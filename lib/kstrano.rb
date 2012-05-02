set :jenkins_base_uri, "" 
set :jenkins_base_job_name, "Default"
set :jenkins_poll_timeout, 300
set :jenkins_poll_interval, 2
set :jenkins_enabled, false

set :campfire_room, nil
set :campfire_token, "" ## kbot
set :campfire_account, "Kunstmaan"

set :airbrake_api_key, nil

# PHP binary to execute
set :php_bin,           "php"
# Symfony console bin
set :symfony_console,     app_path + "/console"


require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/jenkins_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/airbrake_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/campfire_helper.rb"  
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"  
require 'rexml/document'
require 'etc'

namespace :kuma do
  
  desc "Run fixcron for the current project"
  task :fixcron do
    sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixcron.py ] ; then cd /opt/kDeploy/tools/; python fixcron.py #{application}; fi'"
  end
  
  desc "Run fixperms for the current project"
  task :fixperms do
    sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixperms.py ] ; then cd /opt/kDeploy/tools/; python fixperms.py #{application}; fi'"
  end
  
end

namespace :airbrake do
  
  desc "Register a deploy with airbrake.io"
  task :notify do
    if !airbrake_api_key.nil?
      revision = Kumastrano::GitHelper::commit_hash
      repository = Kumastrano::GitHelper::origin_url
      env ||= "production"
      success = Kumastrano::AirbrakeHelper.notify airbrake_api_key, revision, repository, env
      Kumastrano.say "Failed notifying airbrake of the new deploy" unless success
    end
  end
  
end

namespace :campfire do
  
  desc  "Say something on campfire"
  task:say do
    if !campfire_room.nil?
      message = ARGV.join(' ').gsub('campfire:say', '')
      Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, message
      exit
    end
  end
  
end

namespace :jenkins do
  
  desc "create a job for the current branch and application on Jenkins"
  task:create_job do
    ## 1. locate the job in jenkins
    current_branch = Kumastrano::GitHelper.branch_name
    job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
    current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)

    ## 2. if no job was found, first create a job for this branch
    if current_job_url.nil?
      Kumastrano.say "no job found for branch #{current_branch} on #{application}, we'll create one now"
      default_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, jenkins_base_job_name)
      if !default_job_url.nil?
        current_refspec = Kumastrano::GitHelper.origin_refspec
        current_url = Kumastrano::GitHelper.origin_url

        default_job_config = Kumastrano::JenkinsHelper.retrieve_config_xml default_job_url
        document = REXML::Document.new default_job_config
        root = document.root

        ## change the description
        root.elements['description'].text = "This job will be used for testing the branch #{current_branch}"

        ## change the git config
        git_element = root.elements["scm[@class='hudson.plugins.git.GitSCM']"]
        git_element.elements["userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/refspec"].text = current_refspec
        git_element.elements["userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/url"].text = current_url
        git_element.elements["branches/hudson.plugins.git.BranchSpec/name"].text = current_branch

        ## create the new job based on the modified git config
        Kumastrano::JenkinsHelper.create_new_job(jenkins_base_uri, job_name, document.to_s)
        current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)
      end
    else
      Kumastrano.say "there was already a job available on Jenkins for branch #{current_branch} on #{application}"
    end
    
    current_job_url
  end
  
  desc "Try to build the current branch on Jenkins"
  task:build do
    current_job_url = jenkins::create_job
    current_branch = Kumastrano::GitHelper.branch_name
    
    if !current_job_url.nil?
      job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
      prev_build = Kumastrano::JenkinsHelper.last_build_number current_job_url
      Kumastrano.say "start building build ##{(prev_build + 1)} on job #{job_name}, this can take a while"
      
      result, last_build_info = Kumastrano::JenkinsHelper.build_and_wait current_job_url, jenkins_poll_timeout, jenkins_poll_interval

      message = ""
      if result
        Kumastrano.say "the build was succesful"
        message = "was a success"
      else
        Kumastrano.say "the build failed"
        message = "failed"
      end
      
      Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, "#{Etc.getlogin.capitalize} just builded a new version of #{current_branch} on #{application} and it #{message}. You can view the results here #{current_job_url}/lastBuild."
    else
      Kumastrano.say "no job found for #{job_name}, cannot build"
    end
  end
  
end

namespace :deploy do
  
  task :symlink, :except => { :no_release => true } do
      on_rollback do
        if previous_release
          try_sudo "ln -sf #{previous_release} #{current_path}; true"
        else
          logger.important "no previous release to rollback to, rollback of symlink skipped"
        end
      end

      try_sudo "ln -sfT #{latest_release} #{current_path}"
    end
  
end

## Capistrano callbacks ##

# Before deploy:
## Check if there is a build on jenkins. If none is available, it will create one.
## Notify on Campfire what the deployer did.
before :deploy do
  ## only do this in production environment
  if env == 'production' and jenkins_enabled
    can_deploy = false
    current_branch = Kumastrano::GitHelper.branch_name
    current_hash = Kumastrano::GitHelper.commit_hash
      
    if Kumastrano::JenkinsHelper.available? jenkins_base_uri
      ## Allways fetch the latest information from git
      Kumastrano::GitHelper.fetch
  
      job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
      current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)  

      if current_job_url.nil?
        ## No job exists for the current branch, we'll create a job.
        if Kumastrano.ask "no job found for the current branch, do you want to create a job for #{current_branch} on #{application}?", 'y'
          current_job_url = jenkins::create_job
        end
      end

      if !current_job_url.nil?
        ## we have a job url, get info of the lastBuild
        last_build_info = Kumastrano::JenkinsHelper.build_info current_job_url
        result = last_build_info['result'] ## SUCCESS or FAILURE
        build_hash = Kumastrano::JenkinsHelper.fetch_build_hash_from_build_info(last_build_info, current_branch)
  
        if !build_hash.nil?
          if build_hash == current_hash
            if "SUCCESS" == result
              ## The hash of the last build is the same as my hash we can deploy
              can_deploy = true
            else
              ## The hash of the last build is the same as the current hash, but the build failed.
              if Kumastrano.ask "the last build for the branch #{current_branch} for commit #{current_hash} failed, do you want to build again?", 'y'
                prev_build = Kumastrano::JenkinsHelper.last_build_number current_job_url
                Kumastrano.say "start building build ##{(prev_build + 1)} on job #{job_name}, this can take a while"
                result, last_build_info = Kumastrano::JenkinsHelper.build_and_wait current_job_url, jenkins_poll_timeout, jenkins_poll_interval
                new_build_hash = Kumastrano::JenkinsHelper.fetch_build_hash_from_build_info(last_build_info, current_branch)
                if !result.nil? && result && !new_build_hash.nil? && new_build_hash = current_hash
                  can_deploy = true
                else
                  Kumastrano.say "there is still something wrong with #{current_branch} on #{application}, please check manually and try deploying again afterwards!"
                end
              end
            end
          else
            merge_base = Kumastrano::GitHelper.merge_base(build_hash, current_hash)
            if merge_base == build_hash
              ## The build commit is an ancestor of HEAD        
              if Kumastrano.ask "the last build for the branch #{current_branch} is from an older commit do you want to build again? (jenkins=#{build_hash}, local=#{current_hash})", 'y'
                prev_build = Kumastrano::JenkinsHelper.last_build_number current_job_url
                Kumastrano.say "start building build ##{(prev_build + 1)} on job #{job_name}, this can take a while"
                result, last_build_info = Kumastrano::JenkinsHelper.build_and_wait current_job_url, jenkins_poll_timeout, jenkins_poll_interval
                new_build_hash = Kumastrano::JenkinsHelper.fetch_build_hash_from_build_info(last_build_info, current_branch)
                if !result.nil? && result && !new_build_hash.nil? && new_build_hash = current_hash
                  can_deploy = true
                else
                  Kumastrano.say "there is still something wrong with #{current_branch} on #{application}, please check manually and try deploying again afterwards!"
                end
              end
            elsif merge_base == current_hash
              ## The current HEAD is an ancestor of the build hash
              Kumastrano.say "the latest build is of a newer commit, someone else is probably working on the same branch, try updating your local repository first. (jenkins=#{build_hash}, local=#{current_hash})"
            else
              ## Something is wrong, we don't know what try building again
              if Kumastrano.ask "the latest build isn't a valid build, do you want to try building again? (jenkins=#{build_hash}, local=#{current_hash})", 'y'
                prev_build = Kumastrano::JenkinsHelper.last_build_number current_job_url
                Kumastrano.say "start building build ##{(prev_build + 1)} on job #{job_name}, this can take a while"
                result, last_build_info = Kumastrano::JenkinsHelper.build_and_wait current_job_url, jenkins_poll_timeout, jenkins_poll_interval
                new_build_hash = Kumastrano::JenkinsHelper.fetch_build_hash_from_build_info(last_build_info, current_branch)
                if !result.nil? && result && !new_build_hash.nil? && new_build_hash = current_hash
                  can_deploy = true
                else
                  Kumastrano.say "there is still something wrong with #{current_branch} on #{application}, please check manually and try deploying again afterwards!"
                end
              end
            end
          end
        else
          ## No build found, try building it
          if Kumastrano.ask "no build found, do you want to try building it?", 'y'
            prev_build = Kumastrano::JenkinsHelper.last_build_number current_job_url
            Kumastrano.say "start building build ##{(prev_build + 1)} on job #{job_name}, this can take a while"
            result, last_build_info = Kumastrano::JenkinsHelper.build_and_wait current_job_url, jenkins_poll_timeout, jenkins_poll_interval
            new_build_hash = Kumastrano::JenkinsHelper.fetch_build_hash_from_build_info(last_build_info, current_branch)
            if !result.nil? && result && !new_build_hash.nil? && new_build_hash = current_hash
              can_deploy = true
            else
              Kumastrano.say "there is still something wrong with #{current_branch} on #{application}, please check manually and try deploying again afterwards!"
            end
          end
        end
      end
    end
  
    if !can_deploy
      if Kumastrano.ask "no valid build found for #{current_hash} on branch #{current_branch}, do you still want to deploy?"
        Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, "#{Etc.getlogin.capitalize} ignored the fact there was something wrong with #{current_branch} on #{application} and still went on with deploying it!!"
      else
        Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, "#{Etc.getlogin.capitalize} wanted to deploy #{current_branch} on #{application} but there is something wrong with the code, so he cancelled it!"
        exit
      end
    else
      Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, "#{Etc.getlogin.capitalize} is deploying #{current_branch} for #{application}"
    end
  else
    Kumastrano.say "jenkins on demand is disabled, skipping..."
  end
end

# Before update_code:
## Make the cached_copy readable for the current user
before "deploy:update_code" do
  user = Etc.getlogin
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R #{user}:#{user} #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# After update_code:
## Fix the permissions of the cached_copy so that it's readable for the project user
after "deploy:update_code" do
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R #{application}:#{application} #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# Before finalize_update:
## Create the parameters.ini if it's a symfony project
## Fix the permissions of the latest release, so that it's readable for the project user
before "deploy:finalize_update" do
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chmod -R ug+rx #{latest_release}/paramDecode; fi'"
  sudo "sh -c 'if [ -f #{latest_release}/paramDecode ] ; then cd #{latest_release} && ./paramDecode; fi'" # Symfony specific: will generate the parameters.ini
  sudo "chown -R #{application}:#{application} #{latest_release}"
  sudo "setfacl -R -m group:admin:rwx #{latest_release}"
end

# After deploy:
## Notify the people on campfire of this deploy
## Notify airbrake to add a new deploy to the deploy history
after :deploy do
  current_branch = Kumastrano::GitHelper.branch_name
  Kumastrano::CampfireHelper.speak campfire_account, campfire_token, campfire_room, "#{Etc.getlogin.capitalize} successfuly deployed #{current_branch} for #{application}"
  airbrake::notify
  deploy::cleanup ## cleanup old releases
  kuma::fixcron
  try_sudo "sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} apc:clear'"
end
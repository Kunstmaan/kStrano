set :jenkins_base_uri, "http://jenkins.uranus.kunstmaan.be/jenkins" 
set :jenkins_base_job_name, "Default"

set :campfire_room, "OpenMercury.NEXT"
set :campfire_token, "d81bc3243021b0292095216164738cae42b1a3cf"
set :campfire_account, "daanporon"

require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/jenkins_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/capistrano_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"  
require "#{File.dirname(__FILE__)}/helpers/campfire_helper.rb"  
require 'rexml/document'
require 'broach'

namespace :jenkins do
  
  desc "Try to build the current branch on Jenkins"
  task:build do
    
    ## 1. locate the job in jenkins
    current_branch = Kumastrano::GitHelper.branch_name
    job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
    Kumastrano::CapistranoHelper.say("locating job #{job_name}")
    current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)
    
    ## 2. if no job was found, first create a job for this branch
    if current_job_url.nil?
      Kumastrano::CapistranoHelper.say("no job found, start creating one")
      default_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, jenkins_base_job_name)
      if !default_job_url.nil?
        current_refspec = Kumastrano::GitHelper.origin_refspec
        current_url = Kumastrano::GitHelper.origin_url
        
        default_job_config = Kumastrano::JenkinsHelper.retrieve_config_xml(default_job_url)
        document = REXML::Document.new(default_job_config)
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
    end
    
    ## 3. run the build command
    if !current_job_url.nil?
      Kumastrano::CapistranoHelper.say("start building job #{job_name}, this can take a while")
      Kumastrano::JenkinsHelper.build_job(current_job_url)
      ## Wait 5 seconds before polling
      ## Problems with polling
      ## - the build can be put in a queue
      ## - building time can be different each time
      ## - the lastBuild isn't updated directly
      sleep 5
      Kumastrano.poll("A timeout occured", 55) do
        ## wait for the building to be finished
        last_build_info = Kumastrano::JenkinsHelper.build_info(current_job_url)
        result = last_build_info['result'] ## SUCCESS or FAILURE
        building = last_build_info['building']
        "false" == building.to_s && !result.nil?
      end
      Kumastrano::CapistranoHelper.say("done building")
    else
      Kumastrano::CapistranoHelper.say("no job found for #{job_name}, cannot build")
    end
  end
  
end

before :deploy do
  ## Allways fetch the latest information from git
  Kumastrano::GitHelper.fetch
  
  can_deploy = false
  current_branch = Kumastrano::GitHelper.branch_name
  current_hash = Kumastrano::GitHelper.commit_hash
  job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
  current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)  

  if current_job_url.nil?
    ## No job exists for the current branch, we'll create a job and build it. This can take a while.
    if Kumastrano::CapistranoHelper.ask("no job found for the current branch, do you want to create a job for this branch and build it?")
      Kumastrano::CapistranoHelper.say("building #{job_name} can take a while, try to deploying in a couple of minutes")
      jenkins::build
    end
    
    exit
  end
  
  ## If a job exists, get info of the lastBuild
  last_build_info = Kumastrano::JenkinsHelper.build_info(current_job_url)
  result = last_build_info['result'] ## SUCCESS or FAILURE
  actions = last_build_info['actions']
  
  ## Locate the hash of the latest build for my current branch
  build_hash = nil
  actions.each do |list|
    last_revision = list['lastBuiltRevision']
    if !last_revision.nil? && current_branch == last_revision['branch'][0]['name'].sub("origin/", "")
      build_hash = last_revision['branch'][0]['SHA1']
      break
    end
  end
  
  if !build_hash.nil?
    Kumastrano::CapistranoHelper.say("latest build found with hash #{build_hash}, the hash of the current HEAD is #{current_hash}")
    
    if build_hash == current_hash
      if "SUCCESS" == result
        ## The hash of the last build is the same as my hash we can deploy
        can_deploy = true
      else
        ## The hash of the last build is the same as the current hash, but the build failed.
        if Kumastrano::CapistranoHelper.ask("the last build of this commit failed, do you want to build again?")
          jenkins::build
        end
      end
    else
      merge_base = Kumastrano::GitHelper.merge_base(build_hash, current_hash)
      if merge_base == build_hash
        ## The build commit is an ancestor of HEAD        
        Kumastrano::CapistranoHelper.say("the latest build is of an older commit, this can be of one of the following reasons")
        Kumastrano::CapistranoHelper.say("- you have commits which aren't pushed to the server")
        Kumastrano::CapistranoHelper.say("- the server hasn't detected your latest commit")
        if Kumastrano::CapistranoHelper.ask("do you want to try building again?")
          jenkins::build
        end
      elsif merge_base == current_hash
        ## The current HEAD is an ancestor of the build hash
        Kumastrano::CapistranoHelper.say("the latest build is of a newer commit, someone else is probably working on the same branch")
        Kumastrano::CapistranoHelper.say("you can try by pulling the latest code first")
      else
        ## Something is wrong, we don't know what try building again
        if Kumastrano::CapistranoHelper.ask("the latest build isn't a valid build, do you want to try building again?")
          jenkins::build
        end
      end
    end
  else
    ## No build found, try building it
    if Kumastrano::CapistranoHelper.ask("no build found, do you want to try building it?")
      jenkins::build
    end
  end

  if !can_deploy
    Broach.settings = {
      'account' => campfire_account,
      'token' => campfire_token,
      'use_ssl' => true
    }
    puts campfire_room
    puts Broach::Room.find_by_name(campfire_room)
    
    exit
  end
end
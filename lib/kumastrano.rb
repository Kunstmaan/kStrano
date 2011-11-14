set :jenkins_base_uri, "http://jenkins.uranus.kunstmaan.be/jenkins" 
set :jenkins_base_job_name, "Default"

namespace :jenkins do
  
  require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
  require "#{File.dirname(__FILE__)}/helpers/jenkins_helper.rb"
  require 'rexml/document'
  
  desc "Try to build the current branch on Jenkins"
  task:build do
    
    ## 1. locate the job in jenkins
    current_branch = Kumastrano::GitHelper.branch_name
    job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
    say("locating job #{job_name}")
    current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)
    
    ## 2. if no job was found, first create a job for this branch
    if current_job_url.nil?
      say("no job found, start creating one")
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
      say("start building job #{job_name}")
      Kumastrano::JenkinsHelper.build_job(current_job_url)
    else
      say("no job found for #{job_name}, cannot build")
    end
  end
  
end

before :deploy do
  ## Allways fetch the latest information from git
  Kumastrano::GitHelper.fetch
  
  can_deploy = FALSE
  current_branch = Kumastrano::GitHelper.branch_name
  current_hash = Kumastrano::GitHelper.commit_hash
  job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
  current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)  

  if current_job_url.nil?
    ## No job exists for the current branch, we'll create a job and build it. This can take a while.
    if ask("no job found for the current branch, do you want to create a job for this branch and build it?")
      say("building #{job_name} can take a while, try to deploying in a couple of minutes")
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
    say("latest build found with hash #{build_hash}, the hash of the current HEAD is #{current_hash}")
    
    if build_hash == current_hash
      if "SUCCESS" == result
        ## The hash of the last build is the same as my hash we can deploy
        can_deploy = TRUE
      else
        ## The hash of the last build is the same as the current hash, but the build failed.
        if ask("the last build of this commit failed, do you want to build again?")
          jenkins::build
        end
      end
    else
      merge_base = Kumastrano::GitHelper.merge_base(build_hash, current_hash)
      if merge_base == build_hash
        ## The build commit is an ancestor of HEAD        
        say("the latest build is of an older commit, this can be of one of the following reasons")
        say("- you have commits which aren't pushed to the server")
        say("- the server hasn't detected your latest commit")
        if ask("do you want to try building again?")
          jenkins::build
        end
      elsif merge_base == current_hash
        ## The current HEAD is an ancestor of the build hash
        say("the latest build is of a newer commit, someone else is probably working on the same branch")
      else
        ## Something is wrong, we don't know what try building again
        if ask("the latest build isn't a valid build, do you want to try building again?")
          jenkins::build
        end
      end
    end
  else
    ## No build found, try building it
    if ask("no build found, do you want to try building it?")
      jenkins::build
    end
  end

  if !can_deploy
    exit
  end
end

def say(text)
  Capistrano::CLI.ui.say("  * #{text}")
end

def ask(question)
  agree = Capistrano::CLI.ui.agree("    #{question} ") do |q|
    q.default = 'n'
  end
  
  agree
end
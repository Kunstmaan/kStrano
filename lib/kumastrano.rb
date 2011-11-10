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
    Capistrano::CLI.ui.say("    locating job #{job_name}")
    current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)
    
    ## 2. if no job was found, first create a job for this branch
    if current_job_url.nil?
      Capistrano::CLI.ui.say("    no job found, start creating one")
      default_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, jenkins_base_job_name)
      if !default_job_url.nil?
        current_refspec = Kumastrano::GitHelper.origin_refspec
        current_url = Kumastrano::GitHelper.origin_url
        
        default_job_config = Kumastrano::JenkinsHelper.retrieve_config_xml(default_job_url)
        document = REXML::Document.new(default_job_config)
        root = document.root
        
        ## change the description
        root.elements['description'].text = "This job will be used for testing the branch " + current_branch
        
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
      Capistrano::CLI.ui.say("    start building job #{job_name}")
      Kumastrano::JenkinsHelper.build_job(current_job_url)
    else
      Capistrano::CLI.ui.say("    no job found for #{job_name}, cannot build")
    end
  end
  
end

before :deploy do
  current_branch = Kumastrano::GitHelper.branch_name
  job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
  current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)  
  
  ## check if the last build is in the git tree of this commit, if not it means, someone else is also comitting to this branch and testing. Do git pull first
  ## a list of all the builds: http://jenkins.uranus.kunstmaan.be/jenkins/job/OpenMercury.NEXT/api/xml
  ## a list of all the branches for the current build with there current SHA sign: http://jenkins.uranus.kunstmaan.be/jenkins/job/OpenMercury.NEXT/54/api/json

  agree = Capistrano::CLI.ui.agree("    no valid build found for this branch, do you want to build now? ") do |q|
    q.default = 'n'
  end

  if agree
    jenkins::build
  end

  exit
end
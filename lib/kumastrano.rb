namespace :jenkins do
  
  set :jenkins_base_uri, "http://jenkins.uranus.kunstmaan.be/jenkins" 
  set :jenkins_base_job_name, "Default"
  
  require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
  require "#{File.dirname(__FILE__)}/helpers/jenkins_helper.rb"
  require 'rexml/document'
  
  desc "Try to build the current branch on Jenkins"
  task:build do
    
    ## 1. locate the job in jenkins
    current_branch = Kumastrano::GitHelper.branch_name
    job_name = Kumastrano::JenkinsHelper.make_safe_job_name(application, current_branch)
    puts "Locating job #{job_name}"
    current_job_url = Kumastrano::JenkinsHelper.job_url_for_name(jenkins_base_uri, job_name)
    
    ## 2. if no job was found, first create a job for this branch
    if current_job_url.nil?
      puts "No job found, start creating one"
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
      puts "Start building job #{job_name}"
      Kumastrano::JenkinsHelper.build_job(current_job_url)
    end
  end
  
  desc "List jobs"
  task:list_jobs do
    puts Kumastrano::JenkinsHelper.list_jobs(jenkins_base_uri)
  end

  ## puts Kumastrano::GitHelper.git_hash
  
end
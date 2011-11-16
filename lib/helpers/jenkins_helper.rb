module Kumastrano
  class JenkinsHelper
    
    require 'cgi'
    require "net/http"
    require 'uri'
    require 'json'
    
    def self.build_and_wait(job_uri, timeout=60, interval=5)
      success = false
      prev_build = Kumastrano::JenkinsHelper.last_build_number(job_uri)
      Kumastrano.say("Start building ##{(prev_build + 1)}")
      Kumastrano::JenkinsHelper.build_job(job_uri)
      Kumastrano.poll("A timeout occured", timeout, interval) do
        ## wait for the building to be finished
        Kumastrano.say("Waiting")
        last_build_info = Kumastrano::JenkinsHelper.build_info(job_uri)
        result = last_build_info['result'] ## SUCCESS or FAILURE
        building = last_build_info['building']
        number = last_build_info['number']
        if number == (prev_build + 1) && "false" == building.to_s && !result.nil?
          if "SUCCESS" == result
            Kumastrano.say("The build was a success")
            success = true
          else
            success = false
            Kumastrano.say("Building failed")
          end
          true
        else
          false
        end
      end
      success
    end
    
    def self.make_safe_job_name(app_name, branch_name)
      job_name = "#{app_name} (#{branch_name})"
      job_name.gsub(/[#*\/\\]/, "-") # \/#* is unsafe for jenkins job name, because not uri safe
    end
      
    def self.job_url_for_branch(jenkins_base_uri, branch_name)
      current_job_url = nil
      Kumastrano::JenkinsHelper.list_jobs(jenkins_base_uri).each do |job|
        name = job["name"]
        url = job["url"]
        if /.*\(#{branch_name}\)/.match(name)
          current_job_url = url
          break
        end
      end
      current_job_url
    end
    
    def self.job_url_for_name(jenkins_base_uri, job_name)
      current_job_url = nil
      Kumastrano::JenkinsHelper.list_jobs(jenkins_base_uri).each do |job|
        name = job["name"]
        url = job["url"]
        if job_name == name
          current_job_url = url
          break
        end
      end
      current_job_url
    end
    
    def self.list_jobs(base_uri)
      res = get_plain("#{base_uri}/api/json?tree=jobs[name,url]")
      parsed_res = JSON.parse(res.body)["jobs"]
    end
    
    def self.create_new_job(base_uri, job_name, config)
      uri = URI.parse("http://jenkins.uranus.kunstmaan.be/jenkins/createItem/api/json")
      request = Net::HTTP::Post.new(uri.path + "?name=#{CGI.escape(job_name)}")
      request.body = config
      request["Content-Type"] = "application/xml"
      res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(request)}
      if res.code.to_i == 200
        puts "job created"
      else
        puts "job not created"
        puts  res.body
      end
    end
    
    def self.retrieve_config_xml(job_uri)
      res = get_plain("#{job_uri}/config.xml").body
    end
    
    def self.build_job(job_uri)
      res = get_plain("#{job_uri}/build")
      res.code.to_i == 302
    end
    
    def self.last_build_number(job_uri)
      res = get_plain("#{job_uri}/api/json?tree=lastBuild[number]")
      parsed_res = JSON.parse(res.body)
      parsed_res['lastBuild']['number']
    end
    
    def self.build_info(job_uri, build="lastBuild")
      res = get_plain("#{job_uri}/#{build}/api/json")
      parsed_res = JSON.parse(res.body)
    end
    
    private
      
    def self.get_plain(uri)
      uri = URI.parse uri
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.get(uri.path, {}) }
    end
    
  end  
end
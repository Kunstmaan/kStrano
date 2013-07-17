module KStrano
  class JenkinsHelper

    require 'cgi'
    require 'net/http'
    require 'uri'
    require 'json'

    def self.available?(base_uri)
      res = get_plain("#{base_uri}")
      res.code.to_i == 200
    end

    def self.build_and_wait(job_uri, timeout=300, interval=2)
      success = false
      last_build_info = nil
      prev_build = KStrano::JenkinsHelper.last_build_number(job_uri)
      KStrano::JenkinsHelper.build_job(job_uri)
      KStrano.poll("A timeout occured", timeout, interval) do
        ## wait for the building to be finished
        last_build_info = KStrano::JenkinsHelper.build_info(job_uri)
        result = last_build_info['result'] ## SUCCESS or FAILURE
        building = last_build_info['building']
        number = last_build_info['number']
        if number == (prev_build + 1) && "false" == building.to_s && !result.nil?
          if "SUCCESS" == result
            success = true
          else
            success = false
          end
          true
        else
          false
        end
      end
      return success, last_build_info
    end

    def self.fetch_build_hash_from_build_info(build_info, branch_name)
      actions = build_info['actions']

      build_hash = nil
      actions.each do |list|
        last_revision = list['lastBuiltRevision']
        if !last_revision.nil? && branch_name == last_revision['branch'][0]['name'].sub("origin/", "")
          build_hash = last_revision['branch'][0]['SHA1']
          break
        end
      end

      build_hash
    end

    def self.make_safe_job_name(app_name, branch_name)
      job_name = "#{app_name} (#{branch_name})"
      job_name.gsub(/[#*\/\\]/, "-") # \/#* is unsafe for jenkins job name, because not uri safe
    end

    def self.job_url_for_branch(jenkins_base_uri, branch_name)
      current_job_url = nil
      KStrano::JenkinsHelper.list_jobs(jenkins_base_uri).each do |job|
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
      KStrano::JenkinsHelper.list_jobs(jenkins_base_uri).each do |job|
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
      uri = URI.parse("#{base_uri}/createItem/api/json")
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
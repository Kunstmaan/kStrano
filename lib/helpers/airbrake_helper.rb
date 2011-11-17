module Kumastrano
  # Using the gem https://github.com/airbrake/airbrake doesn't work because it's made for rails apps, it needs rake etc. + you need to have the i18n gem
  # This will integrate a very easy command to tell airbrake a deploy has been done
  class AirbrakeHelper
    
    require 'net/http'
    require 'uri'
    require 'etc'
    
    def self.notify
      uri = URI.parse("http://airbrake.io")
      api_key = "c33333081c415f53b35250f74b0546b8"
     
      params = {
        'api_key' => api_key,
        'deploy[rails_env]' => 'production', # Environment of the deploy (production, staging), this needs to be the current environment
        'deploy[scm_revision]' => '79ad52944dc95225b5c21216324e529758239f5a', # The given revision/sha that is being deployed, this needs to be the current_revision variable
        'deploy[scm_repository]' => `git config remote.origin.url`.strip, # Address of your repository to help with code lookups
        'deploy[local_username]' => Etc.getlogin.capitalize # Who is deploying
      }
      
      post = Net::HTTP::Post.new("/deploys")
      post.set_form_data(params)
      
      res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(post)}
      
      if res.code.to_i == 200
        puts "deploy posted"
      else
        puts res.code + " deploy post failed"
      end
      puts  res.body      
    end
  end
end
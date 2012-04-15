module Kumastrano
  # Using the gem https://github.com/airbrake/airbrake doesn't work because it's made for rails apps, it needs rake etc. + you need to have the i18n gem
  # This will integrate a very easy command to tell airbrake a deploy has been done
  class AirbrakeHelper

    require 'net/http'
    require 'uri'
    require 'etc'

    def self.notify(api_key, revision, repository, environment = 'production', username = Etc.getlogin.capitalize)
      uri = URI.parse("http://api.airbrake.io")

      params = {
        'api_key' => api_key,
        'deploy[rails_env]' => environment, # Environment of the deploy (production, staging), this needs to be the current environment
        'deploy[scm_revision]' => revision, # The given revision/sha that is being deployed, this needs to be the current_revision variable
        'deploy[scm_repository]' => repository, # Address of your repository to help with code lookups
        'deploy[local_username]' => username # Who is deploying
      }

      post = Net::HTTP::Post.new("/deploys")
      post.set_form_data(params)

      res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(post)}

      if res.code.to_i == 200
        return true
      else
        return false
      end
    end
  end
end
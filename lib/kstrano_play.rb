module KStrano
  module Play
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        ## Custom stuff here

    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Play.load_into(Capistrano::Configuration.instance)
end
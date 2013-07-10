module KStrano
  module Magento
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        ## Custom stuff here

	    end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Magento.load_into(Capistrano::Configuration.instance)
end
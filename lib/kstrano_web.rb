require 'railsless-deploy'

module KStrano
  module Web
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        set :bundle, false
        set :npm_install, true
        set :bower_install, true
        set :grunt_build, true
        set :group_writable, false

        before "kuma::share_childs" do
          kuma.share_childs
        end

        after "deploy:finalize_update" do
          if bundle
            frontend.bundle.install
          end

          if bower_install
            frontend.bower.install
          end

          if npm_install
            frontend.npm.install
          end

          if grunt_build
            frontend.grunt.build
          end
        end

      end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Web.load_into(Capistrano::Configuration.instance)
end

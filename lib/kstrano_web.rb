require 'railsless-deploy'

module KStrano
  module Web
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        set :bundler_install, false
        set :npm_install, true
        set :bower_install, true
        set :grunt_build, true
        set :gulp_build, false
        set :group_writable, false

        before "kuma::share_childs" do
          kuma.share_childs
        end

        after "deploy:finalize_update" do
          if bundler_install
            frontend.bundler.install
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

          if gulp_build
            frontend.gulp.build
          end
        end

      end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Web.load_into(Capistrano::Configuration.instance)
end

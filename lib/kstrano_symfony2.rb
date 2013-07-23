require 'railsless-deploy'
require 'capifony_symfony2'
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"

module KStrano
  module Symfony2
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        set :php_bin, "php"

        set :copy_vendors, true

        set :force_schema, false
        set :force_migrations, false

        set :dump_assetic_assets, true
        set :interactive_mode, false
        set :clear_controllers, true

        set (:symfony_env_prod) {"#{env}"}

        set :uploaded_files_path, 'web/uploads'

        set :npm_install, false
        set :bower_install, false
        set :grunt_build, false

        namespace :database do
          namespace :move do
            desc "DISABLED"
            task :to_remote, :roles => :db, :only => { :primary => true } do
              KStrano.say "This feature is DISABLED!"
              exit
            end
          end
        end

        namespace :kuma do
          namespace :fpm do
              desc "Reload PHP5 fpm"
              task :reload do
                sudo "/etc/init.d/php5-fpm reload"
              end

              desc "Restart PHP5 fpm"
              task :restart do
                sudo "/etc/init.d/php5-fpm restart"
              end

              desc "Gracefully restart PHP5 fpm"
              task :graceful_restart
                sudo "pkill -QUIT -f \"^php-fpm: pool #{application} \" "
              end
            end
        end

        namespace :deploy do
          desc "Deploy and run pending migrations"
          task :migrations, :roles => :app, :except => { :no_release => true }, :only => { :primary => true } do
            set :force_migrations, true
            deploy.update
            deploy.restart
          end

          desc "Deploy without copying the vendors from a previous install"
          task :clean, :roles => :app, :except => { :no_release => true } do
            set :copy_vendors, false
            deploy.update
            deploy.restart
          end

          namespace :prefer do
            desc "Deploy without copying the vendors from a previous install and use composer option --prefer-source"
            task :source, :roles => :app, :except => { :no_release => true } do
              set :composer_options, "--no-dev --no-scripts --verbose --prefer-source --optimize-autoloader"
              deploy.clean
            end

          end

          namespace :schema do
            desc "Deploy and update the schema"
            task :update, :roles => :app, :except => { :no_release => true }, :only => { :primary => true } do
              set :force_schema, true
              deploy.update
              deploy.restart
            end
          end
        end

        # make it possible to run schema:update and migrations:migrate at the right place in the flow
        after "symfony:bootstrap:build" do
          if model_manager == "doctrine"
            if force_schema
              symfony.doctrine.schema.update
            end

            if force_migrations
              symfony.doctrine.migrations.migrate
            end
          end
        end

        # set the right permissions on the vendor folder ...
        after "symfony:composer:copy_vendors" do
          sudo "sh -c 'if [ -d #{latest_release}/vendor ] ; then chown -R #{application}:#{application} #{latest_release}/vendor; fi'"
        end

        before "kuma:fix:release_permissions" do
          sudo "sh -c 'if [ ! -f #{release_path}/app/config/parameters.ini ] && [ ! -f #{release_path}/app/config/parameters.yml ] ; then if [ -f #{release_path}/paramDecode ] ; then chmod -R ug+rx #{latest_release}/paramDecode && cd #{release_path} && ./paramDecode; elif [ -f #{release_path}/param ] ; then chmod -R ug+rx #{latest_release}/param && cd #{release_path} && ./param decode; fi; fi'"
        end

        ["symfony:composer:install", "symfony:composer:update", "symfony:vendors:install", "symfony:vendors:upgrade"].each do |action|
          after action do |variable|
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

        after "deploy:finalize_update", "kuma:fpm:graceful_restart"
        after "deploy:create_symlink", "kuma:fpm:graceful_restart"

      end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Symfony2.load_into(Capistrano::Configuration.instance)
end

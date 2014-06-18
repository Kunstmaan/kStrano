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
        set :cache_warmup, false
        set :force_schema, false
        set :force_migrations, false
        set :update_assets_version, true
        set :dump_assetic_assets, true
        set :interactive_mode, false
        set :clear_controllers, true
        set (:symfony_env_prod) {"#{env}"}
        set :uploaded_files_path, 'web/uploads'
        set :bundle, false
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
              task :graceful_restart do
                sudo "pkill -QUIT -f \"^php-fpm: pool #{application} \" "
              end
            end

            namespace :apc do
              desc "Prepare for APC cache clear"
              task :prepare_clear do
                server_project_name = "#{server_name}"
                if server_project_name.nil? || server_project_name.empty?
                  server_project_name = domain.split('.')[0]
                end
                sudo "sh -c 'if [ ! -f /home/projects/#{server_project_name}/site/apcclear.php ]; then curl https://raw.github.com/Kunstmaan/kStrano/master/resources/symfony2/apcclear.php > /home/projects/#{server_project_name}/site/apcclear.php; fi'"
                sudo "chmod 777 /home/projects/#{server_project_name}/site/apcclear.php"
              end

              desc "Clear the APC cache"
              task :clear do
                hostname = "#{domain}"
                server_project_name = "#{server_name}"
                if !server_project_name.nil? && !server_project_name.empty?
                  hostname = "#{server_project_name}.#{hostname}"
                end
                sudo "curl http://#{hostname}/apcclear.php"
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

        # set the right permissions on the vendor folder ...
        after "symfony:composer:copy_vendors" do
          sudo "sh -c 'if [ -d #{latest_release}/vendor ] ; then chown -R #{application}:#{application} #{latest_release}/vendor; fi'"
        end

        before "kuma:fix:release_permissions" do
          sudo "sh -c 'if [ ! -f #{release_path}/app/config/parameters.ini ] && [ ! -f #{release_path}/app/config/parameters.yml ] ; then if [ -f #{release_path}/paramDecode ] ; then chmod -R ug+rx #{latest_release}/paramDecode && cd #{release_path} && ./paramDecode; elif [ -f #{release_path}/param ] ; then chmod -R ug+rx #{latest_release}/param && cd #{release_path} && ./param decode; fi; fi'"
        end

        ["symfony:composer:install", "symfony:composer:update", "symfony:vendors:install", "symfony:vendors:upgrade"].each do |action|
          after action do |variable|

            sudo "sh -c 'if [ -f #{release_path}/vendor/sensio/distribution-bundle/Sensio/Bundle/DistributionBundle/Resources/bin/build_bootstrap.php ]; then php #{release_path}/vendor/sensio/distribution-bundle/Sensio/Bundle/DistributionBundle/Resources/bin/build_bootstrap.php; fi'"

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

            if model_manager == "doctrine"
              if force_schema
                symfony.doctrine.schema.update
              end

              if force_migrations
                symfony.doctrine.migrations.migrate
              end
            end
          end
        end

        before "deploy:finalize_update", "kuma:apc:prepare_clear"
        after "deploy:finalize_update", "kuma:apc:clear", "kuma:fpm:graceful_restart"
        after "deploy:create_symlink", "kuma:apc:clear", "kuma:fpm:graceful_restart"

        after "kuma:fpm:graceful_restart", "cache:clear:hard"

        namespace :cache do
          namespace :clear do
            desc "Cache clear using rm -Rf"
            task :hard, :roles => :app, :except => { :no_release => true } do
              run "#{try_sudo} sh -c 'cd #{latest_release} && rm -Rf #{latest_release}/#{cache_path}/*'"
              capifony_puts_ok
            end
          end
        end

      end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Symfony2.load_into(Capistrano::Configuration.instance)
end

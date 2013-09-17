require 'railsless-deploy'
require 'capifony_symfony2'
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"

module KStrano
  module Silex
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        set :php_bin, "php"
        set :copy_vendors, true
        set :interactive_mode, false
        set :cache_warmup, false
        set :use_composer, true
        set :update_vendors, false

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

          desc "Deploy without copying the vendors from a previous install"
          task :clean, :roles => :app, :except => {:no_release => true} do
            set :copy_vendors, false
            deploy.update
            deploy.restart
          end

          namespace :prefer do
            desc "Deploy without copying the vendors from a previous install and use composer option --prefer-source"
            task :source, :roles => :app, :except => {:no_release => true} do
              set :composer_options, "--no-dev --no-scripts --verbose --prefer-source --optimize-autoloader"
              deploy.clean
            end

          end
        end

        # set the right permissions on the vendor folder ...
        after "symfony:composer:copy_vendors" do
          sudo "sh -c 'if [ -d #{latest_release}/vendor ] ; then chown -R #{application}:#{application} #{latest_release}/vendor; fi'"
        end

        before "deploy:finalize_update", "kuma:apc:prepare_clear"
        after "deploy:finalize_update", "kuma:apc:clear", "kuma:fpm:graceful_restart"
        after "deploy:create_symlink", "kuma:apc:clear", "kuma:fpm:graceful_restart"

      end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Silex.load_into(Capistrano::Configuration.instance)
end

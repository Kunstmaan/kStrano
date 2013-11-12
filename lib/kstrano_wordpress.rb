require 'railsless-deploy'
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"

module KStrano
  module Wordpress
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        namespace :deploy do
          desc "Updates latest release source path"
          task :finalize_update, :roles => :app, :except => { :no_release => true } do
            run "#{try_sudo} chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
            kuma::share_childs
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

        before "deploy:finalize_update", "kuma:apc:prepare_clear"
        after "deploy:finalize_update", "kuma:apc:clear", "kuma:fpm:graceful_restart"
        after "deploy:create_symlink", "kuma:apc:clear", "kuma:fpm:graceful_restart"
        end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Wordpress.load_into(Capistrano::Configuration.instance)
end

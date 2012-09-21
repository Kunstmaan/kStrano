# PHP binary to execute
set :php_bin, "php"
# Symfony console bin
set :symfony_console, app_path + "/console"

set :force_schema, false

require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"
require 'rexml/document'
require 'etc'

namespace :kuma do

  desc "Run fixcron for the current project"
  task :fixcron do
    sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixcron.py ] ; then cd /opt/kDeploy/tools/; python fixcron.py #{application}; fi'"
  end

  desc "Run fixperms for the current project"
  task :fixperms do
    sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixperms.py ] ; then cd /opt/kDeploy/tools/; python fixperms.py #{application}; fi'"
  end

  desc "Make the SSH Authentication socket reachable for project user"
  task :fix_ssh_socket do
    sudo "chmod 777 -R `dirname $SSH_AUTH_SOCK`"
  end

  desc "Make the SSH Authentication socket reachable for project user"
  task :unfix_ssh_socket do
    sudo "chmod 775 -R `dirname $SSH_AUTH_SOCK`"
  end

  desc "Reload PHP5 fpm"
  task :fpmreload do
    sudo "/etc/init.d/php5-fpm reload"
  end

  desc "Restart PHP5 fpm"
  task :fpmrestart do
    sudo "/etc/init.d/php5-fpm restart"
  end

  desc "Clear the APC cache"
  task :apcclear do
    serverproject = domain.split('.')[0]
    sudo "sh -c 'curl https://raw.github.com/gist/2868838/ > /home/projects/#{serverproject}/site/apcclear.php'"
    sudo "chmod 777 /home/projects/#{serverproject}/site/apcclear.php"
    sudo "curl http://#{domain}/apcclear.php"
  end

end

namespace :deploy do

  task :create_symlink, :except => { :no_release => true } do
      on_rollback do
        if previous_release
          try_sudo "ln -sf #{previous_release} #{current_path}; true"
        else
          logger.important "no previous release to rollback to, rollback of symlink skipped"
        end
      end
      try_sudo "ln -sfT #{latest_release} #{current_path}"
    end

end

namespace :symfony do

  desc "Copy vendors from previous release"
  task :copy_vendors, :except => { :no_release => true } do
    pretty_print "--> Copying vendors from previous release"
    try_sudo "mkdir #{release_path}/vendor"
    try_sudo "sh -c 'if [ -d #{previous_release}/vendor ] ; then cp -a #{previous_release}/vendor/* #{release_path}/vendor/; fi'"
    puts_ok
  end

  namespace :doctrine do
    namespace :schema do

      desc "Update the database schema."
      task :update do
        if force_schema
          try_sudo "sh -c 'cd #{latest_release} && #{php_bin} #{symfony_console} doctrine:schema:update --env=#{symfony_env_prod} --force'", :once => true
        end
      end

    end
  end

end

before "symfony:vendors:install", "symfony:copy_vendors" # Symfony2 2.0.x
before "symfony:composer:install", "symfony:copy_vendors" # Symfony2 2.1
before "symfony:composer:update", "symfony:copy_vendors" # Symfony2 2.1

# Fix the SSH socket so that it's reachable for the project user, this is needed to pass your local ssh keys to github
before "symfony:vendors:install", "kuma:fix_ssh_socket"
before "symfony:vendors:reinstall", "kuma:fix_ssh_socket"
before "symfony:vendors:upgrade", "kuma:fix_ssh_socket"
before "symfony:composer:update", "kuma:fix_ssh_socket"
before "symfony:composer:install", "kuma:fix_ssh_socket"
after "symfony:vendors:install", "kuma:unfix_ssh_socket"
after "symfony:vendors:reinstall", "kuma:unfix_ssh_socket"
after "symfony:vendors:upgrade", "kuma:unfix_ssh_socket"
after "symfony:composer:update", "kuma:unfix_ssh_socket"
after "symfony:composer:install", "kuma:unfix_ssh_socket"

# ask to update the schema
after "symfony:bootstrap:build", "symfony:doctrine:schema:update"

# clear the cache before the warmup
before "symfony:cache:warmup", "symfony:cache:clear"

# Before update_code:
## Make the cached_copy readable for the current user
before "deploy:update_code" do
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R $SUDO_USER:$SUDO_USER #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# After update_code:
## Fix the permissions of the cached_copy so that it's readable for the project user
after "deploy:update_code" do
  on_rollback { sudo "rm -rf #{release_path}; true" } # by default capistrano will use the run command, but everything has project user rights in our server setup, so use try_sudo in stead of run.
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R #{application}:#{application} #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# Before finalize_update:
## Create the parameters.ini if it's a symfony project
## Fix the permissions of the latest release, so that it's readable for the project user
before "deploy:finalize_update" do
  on_rollback { sudo "rm -rf #{release_path}; true" } # by default capistrano will use the run command, but everything has project user rights in our server setup, so use try_sudo in stead of run.
  sudo "sh -c 'if [ -f #{release_path}/paramDecode ] ; then chmod -R ug+rx #{latest_release}/paramDecode && cd #{release_path} && ./paramDecode; elif [ -f #{release_path}/param ] ; then chmod -R ug+rx #{latest_release}/param && cd #{release_path} && ./param decode; fi'" # Symfony specific: will generate the parameters.ini
  sudo "chown -R #{application}:#{application} #{latest_release}"
  sudo "setfacl -R -m group:admin:rwx #{latest_release}"
end

after "deploy:finalize_update" do
  kuma.fpmreload
  kuma.apcclear
end

before :deploy do
  Kumastrano.say "executing ssh-add"
  %x(ssh-add)
end

# After deploy:
## Notify the people on campfire of this deploy
## Notify airbrake to add a new deploy to the deploy history
after :deploy do
  kuma::fixcron
  deploy::cleanup ## cleanup old releases
end
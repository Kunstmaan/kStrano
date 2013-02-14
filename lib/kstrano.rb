# PHP binary to execute
set :php_bin, "php"

set :copy_vendors, true

set :force_schema, false
set :force_migrations, false

set :webserver_user,    "www-data"
set :permission_method, :acl

set :dump_assetic_assets, true
set :interactive_mode, true
set :clear_controllers, false # set this by default to false, because it's quiet dangerous for existing projects. You need to make sure it doesn't delete your app.php

# http://getcomposer.org/doc/03-cli.md
set :composer_options,      "--no-scripts --verbose --prefer-dist --optimize-autoloader"

require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"
require 'rexml/document'
require 'etc'

namespace :kuma do

  namespace :ssh_socket do

    task :fix do
      sudo "chmod 777 -R `dirname $SSH_AUTH_SOCK`"
    end

    task :unfix do
      sudo "chmod 775 -R `dirname $SSH_AUTH_SOCK`"
    end

  end

  namespace :fix do

    desc "Run fixcron for the current project"
    task :cron do
      sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixcron.py ] ; then cd /opt/kDeploy/tools/; python fixcron.py #{application}; fi'"
    end

    desc "Run fixperms for the current project"
    task :perms do
      sudo "sh -c 'if [ -f /opt/kDeploy/tools/fixperms.py ] ; then cd /opt/kDeploy/tools/; python fixperms.py #{application}; fi'"
    end

  end

  namespace :fpm do

    desc "Reload PHP5 fpm"
    task :reload do
      sudo "/etc/init.d/php5-fpm reload"
    end

    desc "Restart PHP5 fpm"
    task :restart do
      sudo "/etc/init.d/php5-fpm restart"
    end

  end

  namespace :apc do

    desc "Clear the APC cache"
    task :clear do
      serverproject = domain.split('.')[0]
      sudo "sh -c 'curl https://raw.github.com/gist/3987685/ > /home/projects/#{serverproject}/site/apcclear.php'"
      sudo "chmod 777 /home/projects/#{serverproject}/site/apcclear.php"
      sudo "curl http://#{domain}/apcclear.php"
    end

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

  desc "Deploy and run pending migrations"
  task :migrations, :roles => :app, :except => { :no_release => true }, :only => { :primary => true } do
    set :force_migrations, true
    deploy.update
    deploy.restart
  end

  desc "Deploy without copying the vendors from a previous install and use composer option --prefer-source"
  task :prefer_source, :roles => :app, :except => { :no_release => true } do
    set :composer_options, "--no-scripts --verbose --prefer-source --optimize-autoloader"
    deploy.clean
  end

  desc "Deploy without copying the vendors from a previous install"
  task :clean, :roles => :app, :except => { :no_release => true } do
    set :copy_vendors, false
    deploy.update
    deploy.restart
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

# Fix the SSH socket so that it's reachable for the project user, this is needed to pass your local ssh keys to github
before "symfony:vendors:install", "kuma:ssh_socket:fix"
before "symfony:vendors:reinstall", "kuma:ssh_socket:fix"
before "symfony:vendors:upgrade", "kuma:ssh_socket:fix"
before "symfony:composer:update", "kuma:ssh_socket:fix"
before "symfony:composer:install", "kuma:ssh_socket:fix"
after "symfony:vendors:install", "kuma:ssh_socket:unfix"
after "symfony:vendors:reinstall", "kuma:ssh_socket:unfix"
after "symfony:vendors:upgrade", "kuma:ssh_socket:unfix"
after "symfony:composer:update", "kuma:ssh_socket:unfix"
after "symfony:composer:install", "kuma:ssh_socket:unfix"

# clear the cache before the warmup
before "symfony:cache:warmup", "symfony:cache:clear"

# set the right permissions on the vendor folder ... 
after "symfony:composer:copy_vendors" do
  sudo "chown -R #{application}:#{application} #{latest_release}/vendor"
end

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
  kuma.fpm.reload
  kuma.apc.clear
end

before :deploy do
  Kumastrano.say "executing ssh-add"
  %x(ssh-add)
end

after :deploy do
  kuma.fix.cron
  deploy::cleanup ## cleanup old releases
end
# PHP binary to execute
set :php_bin, "php"

set :copy_vendors, true

set :force_schema, false
set :force_migrations, false

set :webserver_user,    "www-data"
set :permission_method, :acl
set :server_name, nil

set :dump_assetic_assets, true
set :interactive_mode, false
set :clear_controllers, false # set this by default to false, because it's quiet dangerous for existing projects. You need to make sure it doesn't delete your app.php

# http://getcomposer.org/doc/03-cli.md
set :composer_options,      "--no-scripts --verbose --prefer-dist --optimize-autoloader"

require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"
require 'rexml/document'
require 'etc'
require 'new_relic/recipes'
require 'new_relic/agent'

namespace :files do
  namespace :move do

    desc "Rsync uploaded files from online to local"
    task :to_local do
      Kumastrano.say "Copying files"
      log = `rsync -qazhL --progress --del --rsh=/usr/bin/ssh -e "ssh -p #{port}" --exclude "*bak" --exclude "*~" --exclude ".*" #{domain}:#{current_path}/web/uploads/* web/uploads/`
      Kumastrano.say log
    end

  end    
end

namespace :kuma do

  namespace :ssh_socket do

    task :fix do
      sudo "chmod 777 -R `dirname $SSH_AUTH_SOCK`"
    end

    task :unfix do
      sudo "chmod 775 -R `dirname $SSH_AUTH_SOCK`"
    end

  end

  desc "Show log of what changed compared to the deployed version"
  task :changelog do
    if releases.length > 0
      Kumastrano::GitHelper.fetch
      changelog = `git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --no-merges #{current_revision}..#{real_revision}`

      if current_revision == real_revision && changelog.strip.empty?
        changelog = "No changes found!"
      end

      Kumastrano.say "Changelog of what will be deployed to #{domain}"
      Kumastrano.say changelog, ''
    end
  end


  namespace :sync do

    desc "sync the database and rsync the files"
    task :to_local do
      files.move.to_local
      Kumastrano.say "Copying database"
      database.move.to_local
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
      if server_name.nil? || server_name.empty?
        server_name = domain.split('.')[0]
      end
      sudo "sh -c 'curl https://raw.github.com/Kunstmaan/kStrano/master/config/apcclear.php > /home/projects/#{server_name}/site/apcclear.php'"
      sudo "chmod 777 /home/projects/#{server_name}/site/apcclear.php"
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

  desc "Deploy without copying the vendors from a previous install"
  task :clean, :roles => :app, :except => { :no_release => true } do
    set :copy_vendors, false
    deploy.update
    deploy.restart
  end

  namespace :prefer do

    desc "Deploy without copying the vendors from a previous install and use composer option --prefer-source"
    task :source, :roles => :app, :except => { :no_release => true } do
      set :composer_options, "--no-scripts --verbose --prefer-source --optimize-autoloader"
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
  sudo "sh -c 'if [ -d #{latest_release}/vendor ] ; then chown -R #{application}:#{application} #{latest_release}/vendor; fi'"
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
## Fix the permissions of the latest release, so that it's readable for the project user
before "deploy:finalize_update" do
  on_rollback { sudo "rm -rf #{release_path}; true" } # by default capistrano will use the run command, but everything has project user rights in our server setup, so use try_sudo in stead of run.
  sudo "chown -R #{application}:#{application} #{latest_release}"
  sudo "setfacl -R -m group:admin:rwx #{latest_release}"
end

after "deploy:finalize_update" do
  kuma.fpm.reload
  kuma.apc.clear
end

# Ensure a stage is specificaly selected
on :start do
  if !stages.include?(ARGV.first)
    Capistrano::CLI.ui.say("You need to select one of the stages first (cap <#{stages.join('|')}> #{ARGV.first})")
    exit
  end
end

before :deploy do
  Kumastrano.say "executing ssh-add"
  %x(ssh-add)

  kuma.changelog
  if !Kumastrano.ask "Are you sure you want to continue deploying?", "y"
    exit
  end
end

after :deploy do
  kuma.fix.cron
 
  if env == "production" && !newrelic_appname.nil? && !newrelic_appname.empty? && !newrelic_license_key.nil? && !newrelic_appname.empty?
    ::NewRelic::Agent.config.apply_config({:license_key => newrelic_license_key}, 1)
    set :newrelic_rails_env, env
    newrelic.notice_deployment
  end

  deploy::cleanup ## cleanup old releases
end

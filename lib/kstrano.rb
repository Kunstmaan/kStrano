require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"

require 'new_relic/recipes'
require 'new_relic/agent'

set :webserver_user,    "www-data"
set :permission_method, :acl
set :server_name, nil
set :port, 22

namespace :files do
  namespace :move do

    desc "Rsync uploaded files from online to local"
    task :to_local do
      KStrano.say "Copying files"
      log = `rsync -qazhL --progress --del --rsh=/usr/bin/ssh -e "ssh -p #{port}" --exclude "*bak" --exclude "*~" --exclude ".*" #{domain}:#{current_path}/#{uploaded_files_path}/* #{uploaded_files_path}/`
      KStrano.say log
    end

  end
end

namespace :kuma do
  desc "Show log of what changed compared to the deployed version"
  task :changelog do
    if releases.length > 0
      KStrano::GitHelper.fetch
      changelog = `git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --no-merges #{current_revision.strip}..#{real_revision.strip}`

      if current_revision.strip == real_revision.strip && changelog.strip.empty?
        changelog = "No changes found!"
      end

      KStrano.say "Changelog of what will be deployed to #{domain}"
      KStrano.say changelog, ''
    end
  end

  namespace :ssh_socket do
    task :fix do
      sudo "chmod 777 -R `dirname $SSH_AUTH_SOCK`"
    end
    task :unfix do
      sudo "chmod 775 -R `dirname $SSH_AUTH_SOCK`"
    end
  end


  namespace :sync do
    desc "sync the database and rsync the files"
    task :to_local do
      files.move.to_local
      KStrano.say "Copying database"
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

namespace :frontend do
  namespace :npm do
    desc "Install the node modules"
    task :install do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && npm install'"
    end
  end

  namespace :bower do
    desc "Install the javascript vendors"
    task :install do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && bower install'"
    end
  end
end

# Fix the SSH socket so that it's reachable for the project user, this is needed to pass your local ssh keys to github
before "symfony:vendors:install", "kuma:ssh_socket:fix"
before "symfony:vendors:reinstall", "kuma:ssh_socket:fix"
before "symfony:vendors:upgrade", "kuma:ssh_socket:fix"
before "symfony:composer:update", "kuma:ssh_socket:fix"
before "symfony:composer:install", "kuma:ssh_socket:fix"
before "symfony:composer:dump_autoload", "kuma:ssh_socket:fix" # The cache folder of composer was the one from the ssh user ... while it should be the one of sudo ...
after "symfony:vendors:install", "kuma:ssh_socket:unfix"
after "symfony:vendors:reinstall", "kuma:ssh_socket:unfix"
after "symfony:vendors:upgrade", "kuma:ssh_socket:unfix"
after "symfony:composer:update", "kuma:ssh_socket:unfix"
after "symfony:composer:install", "kuma:ssh_socket:unfix"
after "symfony:composer:dump_autoload", "kuma:ssh_socket:unfix"

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

before "deploy:update" do
  KStrano.say "executing ssh-add"
  %x(ssh-add)

  kuma.changelog
  if !KStrano.ask "Are you sure you want to continue deploying?", "y"
    exit
  end
end

# Ensure a stage is specificaly selected
on :start do
  if !stages.include?(ARGV.first)
    Capistrano::CLI.ui.say("You need to select one of the stages first (cap <#{stages.join('|')}> #{ARGV.first})")
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

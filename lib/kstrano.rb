require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/kuma_helper.rb"

require 'new_relic/recipes'
require 'new_relic/agent'

set :webserver_user,    "www-data"
set :permission_method, :acl
set :server_name, nil
set :port, 22
set :shared_files, []
set :shared_children, []
set :npm_flags, '--production --silent'

set :copy_bundler_gems, true
set :copy_node_modules, true
set :copy_bower_vendors, true

set :newrelic_appname, ''
set :newrelic_license_key, ''

namespace :files do
  namespace :move do

    desc "Rsync uploaded files from online to local"
    task :to_local do
      KStrano.say "Copying files"
      log = `rsync -qazhL ngress --del --rsh=/usr/bin/ssh -e "ssh -p #{port}" --exclude "*bak" --exclude "*~" --exclude ".*" #{domain}:#{current_path}/#{uploaded_files_path}/* #{uploaded_files_path}/`
      KStrano.say log
    end

  end
end

namespace :kuma do

  # modified version from capifony
  desc "Symlinks static directories and static files that need to remain between deployments"
  task :share_childs, :roles => :app, :except => { :no_release => true } do
    if shared_children
      shared_children.each do |link|
        run "#{try_sudo} mkdir -p #{shared_path}/#{link}"
        run "#{try_sudo} sh -c 'if [ -d #{release_path}/#{link} ] ; then rm -rf #{release_path}/#{link}; fi'"
        run "#{try_sudo} ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"
      end
    end

    if shared_files
      shared_files.each do |link|
        link_dir = File.dirname("#{shared_path}/#{link}")
        run "#{try_sudo} mkdir -p #{link_dir}"
        run "#{try_sudo} touch #{shared_path}/#{link}"
        run "#{try_sudo} ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"
      end
    end
  end

  # modified version from capifony
  desc "Sets permissions for writable_dirs folders as described in the Symfony documentation"
  task :set_permissions, :roles => :app, :except => { :no_release => true } do
    if writable_dirs && permission_method
      dirs = []

      writable_dirs.each do |link|
        if shared_children && shared_children.include?(link)
          absolute_link = shared_path + "/" + link
        else
          absolute_link = latest_release + "/" + link
        end

        dirs << absolute_link
      end

      methods = {
        :chmod => [
          "chmod +a \"#{user} allow delete,write,append,file_inherit,directory_inherit\" %s",
          "chmod +a \"#{webserver_user} allow delete,write,append,file_inherit,directory_inherit\" %s"
        ],
        :acl   => [
          "setfacl -R -m u:#{user}:rwX -m u:#{webserver_user}:rwX %s",
          "setfacl -dR -m u:#{user}:rwx -m u:#{webserver_user}:rwx %s"
        ],
        :chown => ["chown #{webserver_user} %s"]
      }

      if methods[permission_method]
        if fetch(:use_sudo, false)
          methods[permission_method].each do |cmd|
            sudo sprintf(cmd, dirs.join(' '))
          end
        elsif permission_method == :chown
          puts "    You can't use chown method without sudoing"
        else
          dirs.each do |dir|
            is_owner = (capture "`echo stat #{dir} -c %U`").chomp == user
            if is_owner && permission_method != :chown
              methods[permission_method].each do |cmd|
                try_sudo sprintf(cmd, dir)
              end
            else
              puts "    #{dir} is not owned by #{user} or you are using 'chown' method without ':use_sudo'"
            end
          end
        end
      else
        puts "    Permission method '#{permission_method}' does not exist.".yellow
      end
    end
  end

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

    desc "DON'T RUN THIS MANUALLY, is part of the deploy flow"
    task :release_permissions do
      sudo "chown -R #{application}:#{application} #{latest_release}"
      sudo "setfacl -R -m group:admin:rwx #{latest_release}"
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

  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 2).to_i
    try_sudo "ls -1dt --color=never #{releases_path}/* | tail -n +#{count + 1} | #{try_sudo} xargs rm -rf"
  end
end

namespace :frontend do
  namespace :bundler do
    desc "Run bundle install and ensure all gem requirements are met"
    task :install do
      run "#{try_sudo} sh -c 'cd #{latest_release} && bundle install --deployment'"
    end

    task :copy, :except => { :no_release => true } do
      run "#{try_sudo} sh -c 'bundleDir=#{current_path}/vendor/bundle; if [ -d $bundleDir ] || [ -h $bundleDir ]; then cp -a $bundleDir #{latest_release}/vendor/bundle; fi;'"
    end
  end

  namespace :npm do
    desc "Install the node modules"
    task :install do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && npm install #{npm_flags}'"
    end

    task :copy, :except => { :no_release => true } do
      run "#{try_sudo} sh -c 'modulesDir=#{current_path}/node_modules; if [ -d $modulesDir ] || [ -h $modulesDir ]; then cp -a $modulesDir #{latest_release}/node_modules; fi;'"
    end
  end

  namespace :bower do
    desc "Install the javascript vendors"
    task :install do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && bower install --config.interactive=false'"
    end

    task :copy, :except => { :no_release => true } do
      run "#{try_sudo} sh -c 'vendorDir=#{current_path}/web/vendor; if [ -d $vendorDir ] || [ -h $vendorDir ]; then cp -a $vendorDir #{latest_release}/web/vendor; fi;'"
    end
  end

  namespace :grunt do
    desc "Executes the grunt build task"
    task :build do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && grunt build'"
    end
  end

  namespace :gulp do
    desc "Executes the gulp build task"
    task :build do
      run "#{try_sudo} -i sh -c 'cd #{latest_release} && gulp build'"
    end
  end
end

before "frontend:bundler:install" do
  if copy_bundler_gems
    frontend.bundler.copy
  end
end

before "frontend:npm:install" do
  if copy_node_modules
    frontend.npm.copy
  end
end

before "frontend:bower:install" do
  if copy_bower_vendors
    frontend.bower.copy
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
  kuma.fix.release_permissions
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

  if !newrelic_appname.nil? && !newrelic_appname.empty? && !newrelic_license_key.nil? && !newrelic_appname.empty?
    ::NewRelic::Agent.config.apply_config({:license_key => newrelic_license_key}, 1)
    set :newrelic_rails_env, env
    newrelic.notice_deployment
  end

  deploy::cleanup ## cleanup old releases
end

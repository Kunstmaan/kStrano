
set :airbrake_api_key, nil

require "#{File.dirname(__FILE__)}/helpers/git_helper.rb"
require "#{File.dirname(__FILE__)}/helpers/airbrake_helper.rb"
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

end

namespace :airbrake do

  desc "Register a deploy with airbrake.io"
  task :notify do
    if !airbrake_api_key.nil?
      revision = Kumastrano::GitHelper::commit_hash
      repository = Kumastrano::GitHelper::origin_url
      env ||= "production"
      success = Kumastrano::AirbrakeHelper.notify airbrake_api_key, revision, repository, env
      Kumastrano.say "Failed notifying airbrake of the new deploy" unless success
    end
  end

end

namespace :deploy do

  task :symlink, :except => { :no_release => true } do
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

## Capistrano callbacks ##

# Before update_code:
## Make the cached_copy readable for the current user
before "deploy:update_code" do
  user = Etc.getlogin
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R #{user}:#{user} #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# After update_code:
## Fix the permissions of the cached_copy so that it's readable for the project user
after "deploy:update_code" do
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chown -R #{application}:#{application} #{shared_path}/cached-copy; fi'" if deploy_via == :rsync_with_remote_cache || deploy_via == :remote_cache
end

# Before finalize_update:
## Create the parameters.ini if it's a symfony project
## Fix the permissions of the latest release, so that it's readable for the project user
before "deploy:finalize_update" do
  sudo "sh -c 'if [ -d #{shared_path}/cached-copy ] ; then chmod -R ug+rx #{latest_release}/paramDecode; fi'"
  sudo "sh -c 'if [ -f #{latest_release}/paramDecode ] ; then cd #{latest_release} && ./paramDecode; fi'" # Symfony specific: will generate the parameters.ini
  sudo "chown -R #{application}:#{application} #{latest_release}"
  sudo "setfacl -R -m group:admin:rwx #{latest_release}"
end

# After deploy:
## Notify the people on campfire of this deploy
## Notify airbrake to add a new deploy to the deploy history
after :deploy do
  current_branch = Kumastrano::GitHelper.branch_name
  airbrake::notify
  deploy::cleanup ## cleanup old releases
  kuma::fixcron
end
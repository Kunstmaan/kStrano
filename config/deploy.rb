require 'capistrano_colors'

# Main
set :application, ""
set :use_sudo, true
set :admin_runner, ""
set :keep_releases, 5
default_run_options[:pty] = true

# Stages
set :stage_dir, "app/config/deploy"
set :stages, %w{production staging}
set :default_stage, "production"
require 'capistrano/ext/multistage'

set :deploy_to, "/home/projects/#{application}/data/"
set (:domain) {"#{domain}"} # domain is defined in the stage config

role(:web) { domain } # Your HTTP server, Apache/etc
role(:app) { domain } # This may be the same as your `Web` server
role(:db, :primary => true) { domain } # This is where the migrations will run

# Git
set :repository, `git config remote.origin.url`.strip # fetch the repository from git
set :scm, :git
ssh_options[:forward_agent] = true # http://help.github.com/deploy-with-capistrano/
set :deploy_via, :remote_cache #only keeps an online cache
set :branch, "master"

# Symfony 2
set :model_manager, "doctrine"
set :shared_children, [app_path + "/logs", web_path + "/uploads"]
set :vendors_mode, "install"
set :update_vendors, true
set :dump_assetic_assets, true
set :interactive_mode, true
set :use_composer, true
set :clear_controllers, false # This should be fixed, but couldn't get it working with try_sudo

set :writable_dirs,     ["app/cache", "app/logs"]
set :webserver_user,    "www-data"
set :permission_method, :acl
set :force_schema, false

# Logging
# - IMPORTANT = 0
# - INFO      = 1
# - DEBUG     = 2
# - TRACE     = 3
# - MAX_LEVEL = 3
logger.level = Logger::MAX_LEVEL
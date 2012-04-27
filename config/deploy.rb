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

# Symfony 2
set :model_manager, "doctrine"
set :shared_children, [app_path + "/logs", web_path + "/uploads", "vendor"]
set :vendors_mode, "install"
set :update_vendors, true
set :dump_assetic_assets, true
set :update_schema, true
set :force_schema, true
set :do_migrations, false
set :setfacl, true

# Campfire
set :campfire_room, nil

# Airbrake
set :airbrake_api_key, nil

# Jenkins
#:set :jenkins_enabled, true
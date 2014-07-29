set :model_manager, "doctrine"
set :shared_children, [log_path, web_path + "/uploads"]

set :writable_dirs,     ["app/cache", "app/logs"]

set :bundler_install, true
set :npm_install, true
set :bower_install, true
set :grunt_build, false
set :gulp_build, true

# When using Symfony 2.0
# set :use_composer, false
# set :vendors_mode, "install"
# set :update_vendors, true

# When using Symfony 2.1
set :use_composer, true
set :update_vendors, false

set :update_assets_version, true

set :model_manager, "doctrine"
set :shared_children, [log_path, web_path + "/uploads"]

# When using Symfony 2.0
# set :use_composer, false
# set :vendors_mode, "install"
# set :update_vendors, true

# When using Symfony 2.1
set :use_composer, true
set :update_vendors, false

set :writable_dirs,     ["app/cache", "app/logs"]
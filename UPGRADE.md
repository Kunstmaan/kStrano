Upgrade Instructions
====================

### Upgrade to 1.1.0

To upgrade to the new version, make sure you reinstall kstrano

```bash
gem uninstall kstrano
gem install kstrano
gem cleanup railsless-deply, capifony, capistrano
```

After that in every project you must update the Capfile so that it uses the right recipe, for symfony it should look like this:

```bash
load 'deploy' if respond_to?(:namespace) # cap2 differentiator

require 'kstrano_symfony2'
load 'app/config/deploy'
````

### Upgrade to version 0.0.21:

To upgrade to the new version make sure all the previous installs are removed:

```bash
gem uninstall kcapifony
gem uninstall capifony
gem uninstall kstrano
```

After that you can install the new version:

```bash
gem install kstrano
```

Now you need to kumafy every project again, because there are changes in the deploy configuration files which are important, like:
* the vendors which are not shared anymore
* the staging environment for symfony
* the build.xml and other travis configs are updated

To kumafy an existing project use the --force option:

```bash
cd to/your/project/path
kumafy . --force
```

The new config files are made for Symfony version > 2.1 and use composer, to make it work with an older version you need to change

```ruby
set :use_composer, true
set :update_vendors, false
```

to

```ruby
set :use_composer, false
set :vendors_mode, "install"
set :update_vendors, true
```

in your deploy.rb
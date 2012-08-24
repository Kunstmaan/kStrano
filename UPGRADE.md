Upgrade Instructions
====================

# Upgrade to version 0.0.21:

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
set :vendors_mode, "install"
set :update_vendors, true
``` 
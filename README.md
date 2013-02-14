# Introducing [kStrano][kstrano]

[Capistrano][capistrano] is an open source tool for running scripts on multiple servers. It’s primary use is for easily deploying applications. [kStrano][kstrano] (KumaStrano) is a deployment “recipe” to work with Kunstmaan specific applications to make your job a lot easier. It is a wrapper arround [Capifony][capifony].

# Prerequisites

* SSH access to the server you are deploying to
* Must have a working [Ruby][ruby] and [RubyGems][rubygems] installed on your local machine
 * [kStrano][kstrano] has been tested on:
  * OSX Lion using [Ruby][ruby] (1.8.7, 1.9.2), [RubyGems][rubygems] (1.8.10)
  * Ubuntu using [Ruby][ruby] (1.8.7), [RubyGems][rubygems] ()
 * When you still need to install [Ruby][ruby], take a look at [Ruby Version Manager][rvm] or [rbenv][rbenv], which makes installing ruby super easy!
  * [Tutorial on how to install rvm on ubuntu][rvmtut]

* The project for now has only been tested with [Symfony][symfony] projects, to make it work with [Symfony][symfony] we also need the gem [Capifony][capifony].

# Installing [kStrano][kstrano]

Before you install make sure you have no older versions of [kStrano][kstrano] or [Capifony][capifony]:

```bash
gem uninstall capifony
gem uninstall kstrano
```

You can install kStrano using rubyGems:

```bash
gem install kstrano
```

Or you can download the source and install it manually:

```bash
gem build kstrano.gemspec
gem install kstrano-<version>.gem
```

# Configuring your project

```bash
cd to/your/project/path
kumafy .
``` 

You can also do a force install, which will update all the files:

```bash
cd to/your/project/path
kumafy . --force
``` 

by default the configuration files are made for Symfony version > 2.1, and they use composer. To make it work with a version without composer change

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

# Minimal setup

- Add param to your github repo
- Run ./param encode and add app/config/parameters.aes to your github repo
- Commit the changes
- Run ```cap deploy:setup```

From now on you should be able to run ```cap:deploy``` to deploy the project...

# Available [kStrano][kstrano] commands

* cap kuma:fix:cron, this will run the fixcron command on the server from [kDeploy][kdeploy].
* cap kuma:fix:perms, this will run the fixperms command on the server from [kDeploy][kdeploy].
* cap kuma:fpm:reload, this will reload fpm on the server.
* cap kuma:fpm:restart, this will restart fpm on the server.
* cap kuma:apc:clear, this will clear the apc cache. 

# Extra deploy commands which are available through the [kStrano][kstrano] gem:

* cap deploy:migrations, this will deploy and execute the pending migrations
* cap deploy:schema:update, this will deploy and update the schema
* cap deploy:clean, this will deploy without copying the vendors
* cap deploy:prefer_source, this will deploy without copying the vendors and using composer option --prefer-source

# Placing the site in Maintenance mode
To place the site in maintenance mode, we first need to edit the htaccess file to redirect users to the maintenance page.
Place the following snippet in your htaccess file.

```bash
ErrorDocument 503 /web/maintenance.html
RewriteBase /
RewriteCond %{REQUEST_URI} !\.(css|gif|jpg|png)$
RewriteCond %{DOCUMENT_ROOT} /web/maintenance.html -f
RewriteCond %{SCRIPT_FILENAME} !maintenance.html
RewriteCond %{REMOTE_ADDR} !^#Place the allowed ip addresses here
RewriteRule ^.*$  -  [redirect=503,last]
```

This will present the maintenance page to the user if the maintenance.html file is present and the user's IP is not allowed.
To place the site in maintenance mode, issue the next command. 
This command will create a maintenance.html file in your data/releases/*/web directory

```bash
cap deploy:web:disable
```

In order to place the site out of maintenance mode, issue the next command. This command will remove the created 
maintenance.html file that was created by the previous command.

```bash
cap deploy:web:enable
```

##Customizing the maintenance.html
The standard maintenance.html page just states that the site is in maintenance and will be back shortly. 
In order to have a custom maintenance page, you need to set the maintenance_template_path in your deploy.rb.

```bash
set :maintenance_template_path, "location of your custom template"
```

Now you will see your own custom maintenance page. Note that the deploy:web:disable command copies the content from the template to the maintenance.html file. 
So you can not use relative paths in your custom template if you want to show images, custom css etc.

# Changelog

* 13/02/2013 (version 0.0.30)
 * updated to work with [Capifony][capifony] 2.2.7


* 24/08/2012 (version 0.0.21)
 * by default it works with Symfony version > 2.1 now, and it uses composer
 * [kCapifony][kcapifony] isn't needed anymore, from now on it works directly with [Capifony][capifony]
 * updated to work with the new version of [Capifony][capifony]
 * removed vendors from the shared folder to the release folder, and copy it with each deploy
 * clean up the gem no jenkins, campfire and airbrake support anymore
 * added extra commands like fpmreload, fpmrestart, apcclear
 * updated the default config files like: deploy.rb, staging.rb, production.rb, build.xml, etc.
 * fix to make the forward_agent working
 * small fixes

[kstrano]: https://github.com/Kunstmaan/kStrano "kStrano"
[capistrano]: https://github.com/capistrano/capistrano "Capistrano"
[ruby]: http://www.ruby-lang.org/ "Ruby"
[rbenv]: https://github.com/sstephenson/rbenv "Rbenv"
[rubygems]: http://rubygems.org/ "RubyGems"
[capistranoext]: https://github.com/jamis/capistrano-ext "Capistrano Extensions"
[rvm]: http://beginrescueend.com/ "Ruby Version Manager"
[rvmtut]: http://rubysource.com/installing-ruby-with-rvm-on-ubuntu/ "Ruby Version Manager Ubuntu tutorial"
[symfony]: http://symfony.com/ "Symfony"
[capifony]: https://github.com/everzet/capifony "Capifony"
[kcapifony]: https://github.com/Kunstmaan/kCapifony "kCapifony"
[kdeploy]: https://github.com/Kunstmaan/kDeploy "kDeploy"
[kbot]: https://github.com/Kunstmaan/kBot "kBot"

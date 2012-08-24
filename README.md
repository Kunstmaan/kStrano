# Introducing [kStrano][kstrano]

[Capistrano][capistrano] is an open source tool for running scripts on multiple servers. It’s primary use is for easily deploying applications. [kStrano][kstrano] (KumaStrano) is a deployment “recipe” to work with Kunstmaan specific applications to make your job a lot easier.

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

Before you install make sure you have no older versions of [kStrano][kstrano], [Capifony][capifony] or [kCapifony][kcapifony]:

```bash
gem uninstall kcapifony
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

by default the configuration files are made for Symfony version > 2.1, and they use composer. To make it work with a version without compose change

```ruby
set :use_composer, true
set :update_vendors, false
``` 

to 

```ruby
set :vendors_mode, "install"
set :update_vendors, true
``` 

in your deploy.rb

# Minimal setup

- Add paramEncode / paramDecode to your github repo
- Run paramEncode and add app/config/parameters.aes to your github repo
- Commit the changes
- Run ```cap deploy:setup```

From now on you should be able to run ```cap:deploy``` to deploy the project...

# Available [kStrano][kstrano] commands

* cap kuma:fixcron, this will run the fixcron command on the server from [kDeploy][kdeploy].
* cap kuma:fixperms, this will run the fixperms command on the server from [kDeploy][kdeploy].
* cap kuma:fpmreload, this will reload fpm on the server.
* cap kuma:fpmrestart, this will restart fpm on the server.
* cap kuma:apcclear, this will clear the apc cache. 

# Changelog

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
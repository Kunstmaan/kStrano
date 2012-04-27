# Introducing [kStrano][kstrano]

[Capistrano][capistrano] is an open source tool for running scripts on multiple servers. It’s primary use is for easily deploying applications. [kStrano][kstrano] (KumaStrano) is a deployment “recipe” to work with Kunstmaan specific applications to make your job a lot easier. It integrates with:

* [Jenkins][jenkins]
* [Airbrake][airbrake]
* [Campfire][campfire]

When you deploy this will change the [Capistrano][capistrano] deploy flow a bit. It will check if there is a successful build available on [Jenkins][jenkins] for your current commit hash. If not, it will ask if you want to build it again. At the end it will add a Deploy to [Airbrake][airbrake], so that you see which exceptions occurred after your last deploy. In the mean time it will also say some stuff on the configured [Campfire][campfire] room.

# Prerequisites

* SSH access to the server you are deploying to
* Must have a working [Ruby][ruby] and [RubyGems][rubygems] installed on your local machine
 * [kStrano][kstrano] has been tested on:
  * OSX Lion using [Ruby][ruby] (1.8.7, 1.9.2), [RubyGems][rubygems] (1.8.10)
  * Ubuntu using [Ruby][ruby] (1.8.7), [RubyGems][rubygems] ()
 * When you still need to install [Ruby][ruby], take a look at [Ruby Version Manager][rvm], which makes installing ruby super easy!
  * [Tutorial on how to install rvm on ubuntu][rvmtut]
* [Capistrano Extensions][capistranoext] Gem if you need a multistage configuration, the default configuration uses this. If you don't need this you need to remove stuff from your config file.

```bash
gem install capistrano-ext
```
* The project for now has only been tested with [Symfony][symfony] projects, to make it work with [Symfony][symfony] we also need the gem [Capifony][capifony]. We made a forked version of [Capifony][capifony] to work with the server setup at Kunstmaan.

# Installing [kStrano][kstrano]

* Download the Gem file from the [downloads page on Github](https://github.com/Kunstmaan/kStrano/downloads).
* Install the Gem

```bash
gem install kstrano-0.0.1.gem
```

# Installing [Capifony][capifony]

This needs to be done for using [Capistrano][capistrano] in [Symfony][symfony] projects.

* Download the Gem file from the [downloads page on Github](https://github.com/Kunstmaan/capifony/downloads).
* Install the Gem

```bash
gem install capifony-2.1.3.gem
```

# Configuring your project

* First you need to capify or capifonyfy your project, depending if it's a [Symfony][symfony] project or not.

```bash
cd to/your/project/path
capify . or capifony .
```

* After that you can kumafy it.

```bash
cd to/your/project/path
kumafy .
```	

As said before [kStrano][kstrano] only works with [Symfony][symfony] projects for now, so you need to use capifony command. The configuration files created by kumafy will also be [Symfony][symfony] specific.

# Minimal setup

- Add paramEncode / paramDecode to your github repo
- Run paramEncode and add app/config/parameters.aes to your github repo
- Commit the changes
- Run ```cap deploy:setup```

To enable Jenkins on demand building, add the following to deploy.rb

```ruby
set :jenkins_enabled, false, true
``

From now on you should be able to run ```cap:deploy``` to deploy the project...

# Available [kStrano][kstrano] commands

* cap kuma:fixcron, this will run the fixcron command from [kDeploy][kdeploy].
* cap kuma:fixperms, this will run the fixperms command from [kDeploy][kdeploy].
* cap airbrake:notify, this registers an airbrake deploy on [Airbrake][airbrake].
* cap campfire:say, say something as [kBot][kbot] in your room on [Campfire][campfire].
* cap jenkins:build, try to build your current git commit hash in the branch job on [Jenkins][jenkins].
* cap jenkins:create_job, try to create a branch job on [Jenkins][jenkins].
	
# Future improvements

* installing a Gem server on Kunstmaan where we can host our own gems, this will make it easier to install them.

[kstrano]: https://github.com/Kunstmaan/kStrano "kStrano"
[capistrano]: https://github.com/capistrano/capistrano "Capistrano"
[jenkins]: http://jenkins-ci.org/ "Jenkins"
[airbrake]: http://airbrakeapp.com/pages/home "Airbrake"
[campfire]: http://campfirenow.com/ "Campfire"
[ruby]: http://www.ruby-lang.org/ "Ruby"
[rubygems]: http://rubygems.org/ "RubyGems"
[capistranoext]: https://github.com/jamis/capistrano-ext "Capistrano Extensions"
[rvm]: http://beginrescueend.com/ "Ruby Version Manager"
[rvmtut]: http://rubysource.com/installing-ruby-with-rvm-on-ubuntu/ "Ruby Version Manager Ubuntu tutorial"
[symfony]: http://symfony.com/ "Symfony"
[capifony]: https://github.com/Kunstmaan/capifony "Capifony"
[kdeploy]: https://github.com/Kunstmaan/kDeploy "kDeploy"
[kbot]: https://github.com/Kunstmaan/kBot "kBot"
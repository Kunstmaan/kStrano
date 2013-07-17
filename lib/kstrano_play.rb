require 'railsless-deploy'

module KStrano
  module Play
    def self.load_into(configuration)
      configuration.load do

        load_paths.push File.expand_path('../', __FILE__)
        load 'kstrano'

        namespace :deploy do
        	desc "Updates latest release source path"
				  task :finalize_update, :roles => :app, :except => { :no_release => true } do
				    run "#{try_sudo} chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
				    run "#{try_sudo} chmod u+rx #{latest_release}/start.sh"
				    run "#{try_sudo} chmod u+rx #{latest_release}/stop.sh"

				    kuma::share_childs

				    play::package
				  end
        end

        namespace :play do
        	desc "Build the app"
		      task :package do
		        try_sudo "bash -c 'PATH=$PATH:/home/projects/#{application}/play/default:. && cd #{latest_release} && play clean compile stage'"
		      end

		      desc "Start the server"
		      task :start do
		        try_sudo "bash -ic 'cd #{current_path} && PLAY_ENV=#{env} ./start.sh'"
		      end

		      desc "Stop the server"
		      task :stop do
		        try_sudo "bash -c 'cd #{current_path} && ./stop.sh'"
		      end
				end

				after "deploy", "play:stop", "play:start"

			end
    end
  end
end

if Capistrano::Configuration.instance
  KStrano::Play.load_into(Capistrano::Configuration.instance)
end
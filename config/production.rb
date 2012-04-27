set :env, "production"
set :domain, ""

set :apache_runner, 'www-data'

set :branch, `git name-rev --name-only HEAD`.strip # get the current branch name from git

if branch.nil?
  exit
elsif branch != "master"
  agree = Capistrano::CLI.ui.agree("    You are going to execute a deploy command from the #{branch} branch on the production server, are you sure you want to continue?") do |q|
    q.default = 'n'
  end

  if !agree
    exit
  end
end

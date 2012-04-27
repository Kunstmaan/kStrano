set :env, "staging"
set :domain, ""

set :apache_runner, 'www-data'

set :branch, `git name-rev --name-only HEAD`.strip
if branch.nil?
  exit
end
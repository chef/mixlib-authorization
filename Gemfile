source :rubygems

gemspec


gem "rake"

# NOTE: This Gemfile is only used for development or when installed directly.
#
# When used as a library, Rubygems, bundler and friends will consult the
# gemspec.
#
# cf. http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/
#
# As of this writing, our database cookbook will install this library so that
# you can use the Rake tasks to run a schema migration.
#

group(:mysql) do
  gem "mysql2"
end

group(:pg) do
  gem "pg"
end

gem "highline"
gem "rspec"

gem "couchrest", :git => "git://github.com/opscode/couchrest.git"
gem "chef", :git => "git://github.com/opscode/chef.git", :branch => "pl-master", :require => false # load individual parts as needed
gem "opscode-dark-launch", :git => "git@github.com:opscode/opscode-shared", :branch => "master"


group(:test) do
  gem "uuid"
end

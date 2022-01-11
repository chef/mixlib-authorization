source :rubygems

# add dependencies specified in the gemspec file. This is where we pickup sequel
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

gem "pg", "~> 0.16.0"

gem "highline"
gem "rspec"

gem "rest-client", :git => "git://github.com/opscode/rest-client.git", :branch => 'master'
gem "couchrest", :git => "git://github.com/opscode/couchrest.git"
gem "chef", '~> 17.7', :require => false # load individual parts as needed
gem "opscode-dark-launch", :git => "git@github.com:opscode/opscode-shared", :branch => "master"
gem "yajl-ruby"
gem "bunny"

# authentication strategies
gem "net-ldap", "~> 0.2.2"

group(:test) do
  gem "uuid"
end

require 'rubygems'
require 'rubygems/package_task'
require 'rubygems/specification'
require 'date'
require 'rspec/core/rake_task'

spec = eval(File.read("mixlib-authorization.gemspec"))

task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/[m,o]*/**/*_spec.rb'
  t.rspec_opts = %w(-fs --color)
end

desc "Run Functional Tests (Requires Authz)"
RSpec::Core::RakeTask.new(:functional) do |t|
  t.pattern = 'spec/functional/**/*_spec.rb'
  t.rspec_opts = %w(-fs --color)
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the gem locally"
task :install => [:package] do
  sh %{gem install pkg/mixlib-authorization-#{Mixlib::Authorization::VERSION}}
end

desc "remove build files"
task :clean do
  sh %Q{ rm -f pkg/*.gem }
end

desc "Run the specs and functional specs"
task :test => [ :functional, :spec ]

namespace :db do
  desc "Effectively drop the db and then migrate it to current"
  task :remigrate do
    sh("sequel -m db/migrate mysql2://root@localhost/opscode_chef  -M 0")
    sh("sequel -m db/migrate mysql2://root@localhost/opscode_chef")
  end

  desc "Effectively drop the db and then migrate it to current"
  task :remigrate_test do
    sh("sequel -m db/migrate mysql2://root@localhost/opscode_chef_test -M 0")
    sh("sequel -m db/migrate mysql2://root@localhost/opscode_chef_test")
  end

  namespace :production do
    desc "MIGRATE PRODUCTION"
    task :migrate do
      # NOTE: For production we do the migration manually instead of shelling
      # out to `sequel -m` so that we never enter the root database password in
      # the argv of a command (where it could be seen in `ps`).
      #
      # This code duplicates the functionality of bin/sequel in the sequel gem.

      require 'sequel'
      require 'mysql2'
      require 'highline'
      require 'logger'
      logger = Logger.new(STDOUT)
      migrate_dir = File.expand_path("../db/migrate", __FILE__)

      connection_string = "mysql2://root:%s@localhost/opscode_chef"
      puts "** MIGRATING PRODUCTION **"
      puts connection_string % "PASSWORD"

      root_passwd = HighLine.new.ask("Database root password: ") {|q| q.echo = false}
      db = Sequel.connect(connection_string % root_passwd, :loggers => [logger])

      Sequel.extension :migration
      Sequel::Migrator.apply(db, migrate_dir, nil)

    end
  end

end



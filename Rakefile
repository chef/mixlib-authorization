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

require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'

spec = eval(File.read("mixlib-authorization.gemspec"))

task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = %w(-fs --color)
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the gem locally"
task :install => [:package] do
  sh %{gem install pkg/mixlib-authorization-#{MIXLIB_AUTHORIZATION_VERSION}}
end

desc "create a gemspec file"
task :make_spec do
  File.open("mixlib-authorization.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

Cucumber::Rake::Task.new(:features) do |t|
  t.profile = "default"
end

desc "remove build files"
task :clean do
  sh %Q{ rm -f pkg/*.gem }
end

desc "Run the spec and features"
task :test => [ :features, :spec ]

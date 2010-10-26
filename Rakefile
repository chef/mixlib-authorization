require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'spec/rake/spectask'
require 'cucumber/rake/task'

spec = eval(File.read("mixlib-authorization.gemspec"))

task :default => :spec

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = %w(-fs --color)
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the gem locally"
task :install => [:package] do
  sh %{gem install pkg/#{GEM}-#{GEM_VERSION}}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{GEM}.gemspec", "w") do |file|
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

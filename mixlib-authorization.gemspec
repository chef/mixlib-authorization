$:.unshift(File.expand_path("../lib", __FILE__))
require 'mixlib/authorization/version'

Gem::Specification.new do |s|
  s.name = "mixlib-authorization"
  s.version = Mixlib::Authorization::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE", 'NOTICE']
  s.summary = "Helpers for request authorization"
  s.description = s.summary
  s.author = "Opscode, Inc."
  s.email = "info@opscode.com"
  s.homepage = "http://www.opscode.com"

  # Uncomment this to add a dependency
  s.add_dependency "mixlib-authentication"
  s.add_dependency "mixlib-log"
  s.add_dependency "mixlib-config"
  s.add_dependency "rest-client"

  s.add_dependency "sequel", "~> 3.34.1"

  # Pinning this to a pre-4.0.0 version.  Updating to 4.0.0+ will
  # require changes to our regular expressions; see
  # https://github.com/rails/rails/blob/4-0-stable/activemodel/CHANGELOG.md
  # (last entry) and
  # http://edgeguides.rubyonrails.org/security.html#regular-expressions.
  s.add_dependency "activemodel", "~> 3.2.2"

  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile NOTICE) + Dir.glob("{lib,spec,features}/**/*")
end

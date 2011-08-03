MIXLIB_AUTHORIZATION_VERSION = "1.2.1"

Gem::Specification.new do |s|
  s.name = "mixlib-authorization"
  s.version = MIXLIB_AUTHORIZATION_VERSION
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

  s.add_dependency "sequel"
  s.add_dependency "mysql2"
  s.add_dependency "activemodel"

  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile NOTICE) + Dir.glob("{lib,spec,features}/**/*")
end

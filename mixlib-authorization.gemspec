GEM = "mixlib-authorization"
GEM_VERSION = "1.2.0"

Gem::Specification.new do |s|
  s.name = GEM
  s.version = GEM_VERSION
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
  
  s.require_path = 'lib'
  s.autorequire = GEM
  s.files = %w(LICENSE README.rdoc Rakefile NOTICE) + Dir.glob("{lib,spec,features}/**/*")
end
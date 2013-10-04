require 'pp'
require 'rubygems'

canonical_libname = lambda { |f| f.gsub(%r{.rb$}, '') }
require_lib = lambda { |lib| require lib }

# Loads all of lib. This is a bit of cheating but we won't be using this for long.
Dir[File.join(File.dirname(__FILE__), '..', 'lib', '**', '*.rb')].sort.map(&canonical_libname).each(&require_lib)

gem "rest-client", ">= 1.0.3"

$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib/")
$:.unshift '.'

Dir["spec/support/**/*.rb"].map(&canonical_libname).each(&require_lib)

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true

  # If you just want to run one (or a few) tests in development,
  # add :focus metadata
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
end

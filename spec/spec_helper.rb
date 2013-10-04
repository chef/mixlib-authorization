require 'pp'
require 'rubygems'

gem "rest-client", ">= 1.0.3"

$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib/")
$:.unshift '.'

Dir["spec/support/**/*.rb"].map { |f| f.gsub(%r{.rb$}, '') }.each { |f| require f }

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true

  # If you just want to run one (or a few) tests in development,
  # add :focus metadata
  c.filter_run :focus => true
  c.run_all_when_everything_filtered = true
end

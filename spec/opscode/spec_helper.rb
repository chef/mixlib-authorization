require 'pp'
require 'rubygems'

$:.unshift File.expand_path("../../../lib/", __FILE__)

require 'opscode/models/user'
require 'opscode/mappers/user'

include Opscode::Models

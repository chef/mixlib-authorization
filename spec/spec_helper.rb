require 'pp'
require 'rubygems'
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib/")
require "mixlib/authorization"
require 'mixlib/authorization/auth_helper'
require "mixlib/authorization/acl"
require 'mixlib/authorization/request_authentication'

include Mixlib::Authorization
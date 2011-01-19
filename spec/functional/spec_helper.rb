require 'pp'
require 'rubygems'

require 'uuid'
gem "rest-client", ">= 1.0.3"
require "couchrest"
require "yajl"

$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib/")

## TODO ##
# This is seriously a lot of work to configure this stuff
# It should be easier, DRYer and less dependent on ordering
##########
account_database = 'opscode_account_functional_test'
internal_database = 'opscode_account_internal_functional_test'
# private_key = OpenSSL::PKey::RSA.new(File.read('/etc/opscode/azs.pem'))
# webui_public_key = OpenSSL::PKey::RSA.new(File.read('/etc/opscode/webui_pub.pem'))
couchdb_uri = 'localhost:5984'
authorization_service_uri = 'http://localhost:5959'
#certificate_service_uri = 'http://localhost:5140/certificates'

## FAILSAFES ##
# These are functional tests and don't mock things out. Deal with it.
# Because I'm nice, Imma make sure the services you need are running before
# starting the tests.
###############
# CouchDB Failsafe
begin
  url_with_proto = "http://#{couchdb_uri}"
  RestClient.get(url_with_proto)
rescue
  STDERR.puts(<<-FAIL)
#{'#' * 80}
Could not connect to CouchDB at #{url_with_proto}
You need a working CouchDB and Authz Service to run these tests.
#{'#' * 80}
FAIL
  raise
end
# Authz Failsafe
begin
  RestClient.get(authorization_service_uri)
rescue RestClient::ResourceNotFound
  # Authz returns 404s from its root URL, so we're cool.
rescue
  STDERR.puts(<<-FAIL)
#{'#' * 80}
Could not connect to an Opscode Authz service at #{authorization_service_uri}
You need a working CouchDB and Authz Service to run these tests.
#{'#' * 80}
FAIL
  raise
end

couchrest = CouchRest.new(couchdb_uri)
couchrest.database!(account_database)
couchrest.default_database = account_database

couchrest_internal = CouchRest.new(couchdb_uri)
couchrest_internal.database!(internal_database)
couchrest_internal.default_database = internal_database
  
require 'mixlib/authorization'
Mixlib::Authorization::Config.couchdb_uri = couchdb_uri
Mixlib::Authorization::Config.default_database = couchrest.default_database
Mixlib::Authorization::Config.internal_database = couchrest_internal.default_database
#Mixlib::Authorization::Config.private_key = private_key
#Mixlib::Authorization::Config.web_ui_public_key = webui_public_key
Mixlib::Authorization::Config.authorization_service_uri = authorization_service_uri
#Mixlib::Authorization::Config.certificate_service_uri = certificate_service_uri
require 'mixlib/authorization/auth_join'
require 'mixlib/authorization/models'

require 'mixlib/authorization/auth_helper'
require "mixlib/authorization/acl"
require 'mixlib/authorization/request_authentication'
require 'mixlib/authorization/join_helper'

include Mixlib::Authorization

Mixlib::Authorization::Log.init(STDERR)
Mixlib::Authorization::Log.level = :debug if ENV["DEBUG"]

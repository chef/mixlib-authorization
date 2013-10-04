require "mixlib/authorization"
require 'mixlib/authorization/auth_helper'
require "mixlib/authorization/acl"
require 'mixlib/authorization/request_authentication'

require 'opscode/models/user'

Mixlib::Authorization::Config.authorization_service_uri ||= 'http://localhost:9463'

def mk_actor() 
  begin  
    uri = "#{Mixlib::Authorization::Config.authorization_service_uri}/actors"
    resp = RestClient.post uri, '{}', :content_type => 'application/json'
    actor =  JSON::parse(resp)["id"]
  rescue Exception => e
    puts "Can't create dummy actor id with uri #{uri}"
    exit
  end 
end

Mixlib::Authorization::Config.dummy_actor_id = mk_actor()
Mixlib::Authorization::Config.other_actor_id1 = mk_actor()
Mixlib::Authorization::Config.other_actor_id2 = mk_actor()

# Mixlib::Authorization::Config.dummy_actor_id = "5ca1ab1ef005ba111abe11eddecafbad"

puts "Using dummy_actor_id #{Mixlib::Authorization::Config.dummy_actor_id}"

Mixlib::Authorization::Config.superuser_id = "5ca1ab1ef005ba111abe11eddecafbad"

include Mixlib::Authorization

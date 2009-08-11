#
# Author:: Nuo Yan <nuo@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'openssl'
require 'opscode/rest'

module Mixlib
  module Authorization
    module AuthHelper
      
      def gen_cert(guid)
        begin
          rest = Opscode::REST::Resource.new(Merb::Config[:certificateservice_uri])
          #common name is in the format of: "URI:http://opscode.com/GUIDS/...."
          common_name = "URI:http://opscode.com/GUIDS/#{guid.to_s}"
          response = JSON.parse(rest.post({:common_name => common_name}))
          #certificate
          cert = OpenSSL::X509::Certificate.new(response["cert"])
          #private key
          key = OpenSSL::PKey::RSA.new(response["keypair"])
          [cert.public_key, key]
        rescue
          raise AuthorizationException, "Failed to generate cert: #{$!}"
        end
      end

      def gen_guid(value=nil)
        http = Net::HTTP.new(Merb::Config[:guidservice_host], Merb::Config[:guidservice_port])
        value ||= "This GUID brought to you by #{self.class}"
        resp = http.request_post('/GUIDS', value.to_s)
        case resp
        when Net::HTTPSuccess, Net::HTTPRedirection
          # Guid for the user's credentials
          resp["Location"].sub!("/GUIDS/", "")
        else
          raise AuthorizationException, "Failed to create object GUID"
        end
      end

      def orgname_to_dbname(orgname)
        guid = guid_from_orgname(orgname).downcase
        dbname = "chef_#{guid}"
        Mixlib::Authorization::Log.debug "In auth_helper, orgname_to_dbname, orgname: #{orgname}, dbname: #{dbname}"
        dbname
      end

      def database_from_orgname(orgname)
        Mixlib::Authorization::Log.debug "In auth_helper, database_from_orgname, orgname: #{orgname}"
        dbname = orgname_to_dbname(orgname)
        CouchRest.new(Merb::Config[:couchdb_uri]).database!(dbname)
        CouchRest::Database.new(CouchRest::Server.new(Merb::Config[:couchdb_uri]),dbname)
      end
      
      def guid_from_orgname(orgname)
        Mixlib::Authorization::Log.debug "In auth_helper, guid_from_orgname, orgname: #{orgname}"
        organization = Mixlib::Authorization::Models::Organization.find(orgname)
        organization["guid"]
      end 

      def user_to_actor(user_id)
        raise ArgumentError, "must supply user_id" unless user_id
        actor = AuthJoin.by_user_object_id(:key=>user_id).first
        Mixlib::Authorization::Log.debug("in user to actor: user: #{user_id}, actor:#{actor.inspect}")
        actor
      end

      def actor_to_user(actor, org_database)
        raise ArgumentError, "must supply actor" unless actor
        Mixlib::Authorization::Log.debug("actor to user: actor: #{actor}")
        user_object_id = AuthJoin.by_auth_object_id(:key=>actor).first.user_object_id
        user = begin
                 Mixlib::Authorization::Models::User.get(user_object_id)
               rescue RestClient::ResourceNotFound
                 Mixlib::Authorization::Models::Client.on(org_database).get(user_object_id)
               end
        Mixlib::Authorization::Log.debug("user: #{user.inspect}")
        user
      end

      def auth_group_to_user_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        Mixlib::Authorization::Log.debug("auth group to user group: #{group_id}, database: #{org_database.inspect}")
        auth_join = AuthJoin.by_auth_object_id(:key=>group_id).first
        user_group = Mixlib::Authorization::Models::Group.on(org_database).get(auth_join.user_object_id).groupname
        Mixlib::Authorization::Log.debug("user group: #{user_group}")
        user_group
      end

      def user_group_to_auth_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        Mixlib::Authorization::Log.debug("user group to auth group: #{group_id}, database: #{org_database.inspect}")        
        group_obj = Mixlib::Authorization::Models::Group.on(org_database).by_groupname(:key=>group_id).first
        auth_join = AuthJoin.by_user_object_id(:key=>group_obj["_id"]).first
        Mixlib::Authorization::Log.debug("auth_join: #{auth_join.inspect}")
        auth_group = auth_join.auth_object_id
        Mixlib::Authorization::Log.debug("auth group: #{auth_group}")
        auth_group
      end
      
      def transform_names_to_auth_ids(database, actors_by_type)
        raise ArgumentError, "Must supply actors!" unless actors_by_type

        actornames = actors_by_type["users"] || []
        clientnames = actors_by_type["clients"] || []
        groupnames = actors_by_type["groups"] || []
        
        actor_ids = actornames.inject([]) do |memo, actorname|
          user = Mixlib::Authorization::Models::User.find(actorname)
          auth_join = AuthJoin.by_user_object_id(:key=>user.id).first
          memo << auth_join.auth_object_id
        end

        client_ids = clientnames.inject([]) do |memo, clientname|
          client = Mixlib::Authorization::Models::Client.on(database).by_clientname(:key=>clientname).first
          auth_join = AuthJoin.by_user_object_id(:key=>client.id).first
          memo << auth_join.auth_object_id
        end

        actor_ids += client_ids
        
        group_ids = groupnames.inject([]) do |memo, groupname|
          group = Mixlib::Authorization::Models::Group.on(database).by_groupname(:key=>groupname).first
          auth_join = AuthJoin.by_user_object_id(:key=>group.id).first
          memo << auth_join.auth_object_id
        end

        [actor_ids, group_ids]
      end
      
      def check_rights(params)
        raise ArgumentError, "bad arg to check_rights" unless params.respond_to?(:has_key?)
        Mixlib::Authorization::Log.debug("check rights params: #{params.inspect}")
        object = params[:object]
        Mixlib::Authorization::Log.debug("check rights object: #{object.inspect}")      
        actor = params[:actor]
        ace = params[:ace].to_s
        object.is_authorized?(actor,ace)
      end
      
      def transform_actor_ids(incoming_actors, org_database, direction)
        outgoing_actors = []
        incoming_actors.each { |incoming_actor|
          actor = case direction
                  when  :to_user
                    user = actor_to_user(incoming_actor, org_database)
                    (user.respond_to?(:username) ? user.username : user.clientname)
                  when  :to_auth
                    user = begin
                             Mixlib::Authorization::Models::User.find(incoming_actor)
                           rescue ArgumentError
                             Mixlib::Authorization::Models::Client.on(org_database).by_clientname(:key=>incoming_actor).first
                           end
                    actor = user_to_actor(user.id)
                    actor.auth_object_id
                  end
          outgoing_actors << actor
        }
        outgoing_actors        
      end

      def transform_group_ids(incoming_groups, org_database, direction)
        outgoing_groups = []
        incoming_groups.each{ |incoming_group|
          group = case direction
                  when  :to_user
                    auth_group_to_user_group(incoming_group, org_database)
                  when  :to_auth
                    user_group_to_auth_group(incoming_group, org_database)
                  end

          outgoing_groups << group
        }
        outgoing_groups      
      end      
    end
    
    class Acl
      include Mixlib::Authorization::AuthHelper
      
      ACES = ["create","read","update","delete","grant"] 
      attr_reader :org_database
      attr_reader :direction
      attr_reader :aces
      
      def initialize(orgname, acl_data, acl_direction=:to_user)
        @org_database = (orgname.nil? ? nil : database_from_orgname(orgname))
        @aces = { }
        @direction = acl_direction
        Acl::ACES.each do |ace|
          @aces[ace] = { "actors" => transform_actor_ids(acl_data[ace]["actors"], org_database, direction),
            "groups"=>transform_group_ids(acl_data[ace]["groups"], org_database, direction)}
        end
      end
      
 
      
      def for_json
        @aces
      end
      
    end
  end
end

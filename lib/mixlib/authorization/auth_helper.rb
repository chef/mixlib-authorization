#
# Author:: Nuo Yan <nuo@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'openssl'
require 'rest_client'

module Mixlib
  module Authorization
    module AuthHelper
      
      def gen_cert(guid, rid=nil)
        begin
          Mixlib::Authorization::Log.debug "auth_helper.rb: certificate_service_uri is #{Mixlib::Authorization::Config.certificate_service_uri}"

          #common name is in the format of: "URI:http://opscode.com/GUIDS/...."
          common_name = "URI:http://opscode.com/GUIDS/#{guid}"

          # response = (rid == nil ? rest.post({:common_name => common_name}) : rest.post({:common_name => common_name}, rid) )
          # BUGBUG What about the rid? [cb]
          response = JSON.parse(RestClient.post Mixlib::Authorization::Config.certificate_service_uri, :common_name => common_name)

          # Opscode::REST will return a hash only if the certificate service
          # returned a document with the mime type 'application/json'. 
          # opscode-certificate returns text/html and opscode-cert-gen
          # returns 'application/json'

          #certificate
          cert = OpenSSL::X509::Certificate.new(response["cert"])
          #private key
          key = OpenSSL::PKey::RSA.new(response["keypair"])
          [cert, key]
        rescue StandardError => se
          se_backtrace = se.backtrace.join("\n")
          Mixlib::Authorization::Log.error "Exception in gen_cert: #{se}\n#{se_backtrace}"
          raise Mixlib::Authorization::AuthorizationError, "Failed to generate cert: #{$!}", se.backtrace
        end
      end

      def orgname_to_dbname(orgname)
        (guid = guid_from_orgname(orgname)) && "chef_#{guid.downcase}"
      end

      def database_from_orgname(orgname)
        raise ArgumentError, "Must supply orgname" if orgname.nil? or orgname.empty?
        dbname = orgname_to_dbname(orgname)
        if dbname
          uri = Mixlib::Authorization::Config.couchdb_uri
          CouchRest.new(uri).database!(dbname)
          CouchRest::Database.new(CouchRest::Server.new(uri),dbname)
        end
      end
      
      def guid_from_orgname(orgname)
        (org = Mixlib::Authorization::Models::Organization.by_name(:key => orgname).first) && org["guid"]
      end 

      def user_to_actor(user_id)
        raise ArgumentError, "must supply user_id" unless user_id
        actor = AuthJoin.by_user_object_id(:key=>user_id).first
        Mixlib::Authorization::Log.debug("in user to actor: user: #{user_id}, actor:#{actor.inspect}")
        actor
      end

      def actor_to_user(actor, org_database)
        raise ArgumentError, "must supply actor" unless actor
        user_object = AuthJoin.by_auth_object_id(:key=>actor).first
        
        user = begin
                 user_object && Mixlib::Authorization::Models::User.get(user_object.user_object_id)
               rescue RestClient::ResourceNotFound
                 Mixlib::Authorization::Models::Client.on(org_database).get(user_object.user_object_id)
               rescue StandardError=>se
                 Mixlib::Authorization::Log.error "Failed to turn actor #{actor} into a user or client: #{se}"
                 nil
               end
        
        Mixlib::Authorization::Log.debug("actor to user: actor: #{actor}, user or client name #{user.nil? ? nil : user.respond_to?(:username) ? user.username : user.clientname}")
        user
      end

      def auth_group_to_user_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        Mixlib::Authorization::Log.debug("auth group to user group: #{group_id}, database: #{org_database && org_database.name}")
        auth_join = AuthJoin.by_auth_object_id(:key=>group_id).first
        user_group = begin
                       Mixlib::Authorization::Models::Group.on(org_database).get(auth_join.user_object_id).groupname
                     rescue StandardError=>se
                       Mixlib::Authorization::Log.error "Failed to turn auth group id #{group_id} into a user-side group: #{se}"
                       nil
                     end

        Mixlib::Authorization::Log.debug("user group: #{user_group}")
        user_group
      end

      def user_group_to_auth_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        group_obj = Mixlib::Authorization::Models::Group.on(org_database).by_groupname(:key=>group_id).first
        Mixlib::Authorization::Log.debug("user-side group: #{group_obj.inspect}")
        auth_join = group_obj && AuthJoin.by_user_object_id(:key=>group_obj["_id"]).first
        Mixlib::Authorization::Log.debug("user group to auth group: #{group_id}, database: #{org_database && org_database.name},\n\tuser_group: #{group_obj.inspect}\n\tauth_join: #{auth_join.inspect}")
        raise Mixlib::Authorization::AuthorizationError, "failed to find group or auth object!" if auth_join.nil?
        auth_group = auth_join.auth_object_id
        Mixlib::Authorization::Log.debug("auth group: #{auth_group}")
        auth_group
      end
      
      def check_rights(params)
        raise ArgumentError, "bad arg to check_rights" unless params.respond_to?(:has_key?)
        Mixlib::Authorization::Log.debug("check rights params: #{params.inspect}")
        params[:object].is_authorized?(params[:actor],params[:ace].to_s)
      end
      
      def user_or_client_by_name(ucname, org_database)
        user = (Mixlib::Authorization::Models::User.by_username(:key=>ucname).first || Mixlib::Authorization::Models::Client.on(org_database).by_clientname(:key=>ucname).first)
        Mixlib::Authorization::Log.debug("user or client by name, name #{ucname}, org database, #{org_database}, user: #{user.class}, #{user.nil? ? nil : user.respond_to?(:username) ? user.username : user.clientname}")
        user
      end
      
      def transform_actor_ids(incoming_actors, org_database, direction)
        incoming_actors.inject([]) do |outgoing_actors, incoming_actor|
          actor = case direction
                  when :to_user
                    (user_or_client = actor_to_user(incoming_actor, org_database)) && ((user_or_client.respond_to?(:username) && user_or_client.username) || user_or_client.clientname )
                  when :to_auth
                    (user = user_or_client_by_name(incoming_actor,org_database)) && user_to_actor(user.id).auth_object_id
                  end
          Mixlib::Authorization::Log.debug "incoming_actor: #{incoming_actor} is not a recognized user or client!" if actor.nil?
          (actor.nil? ? outgoing_actors : outgoing_actors << actor)
        end
      end

      def transform_group_ids(incoming_groups, org_database, direction)
        incoming_groups.inject([]) do |outgoing_groups, incoming_group|
          group = case direction
                  when  :to_user
                    auth_group_to_user_group(incoming_group, org_database)
                  when  :to_auth
                    user_group_to_auth_group(incoming_group, org_database)
                  end
          Mixlib::Authorization::Log.debug "incoming_group: #{incoming_group} is not a recognized group!" if group.nil?          
          group.nil? ? outgoing_groups : outgoing_groups << group 
        end
      end
      
      def get_global_admins_groupname(orgname)
        "#{orgname}_global_admins"
      end
      
    end

  end
end

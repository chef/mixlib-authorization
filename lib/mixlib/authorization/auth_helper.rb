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

      class OrgGuidMap
        def initialize
          @cached_map = {}
          @caching = false
        end

        def enable_caching
          @caching = true
        end

        def disable_caching
          @caching = false
        end

        def guid_for_org(orgname)
          @caching ? lookup_with_caching(orgname) : lookup_without_caching(orgname)
        end

        private

        def lookup_with_caching(orgname)
          if guid = @cached_map[orgname]
            guid
          else
            @cached_map[orgname] = lookup_without_caching(orgname)
          end
        end

        def lookup_without_caching(orgname)
          org = Mixlib::Authorization::Models::Organization.by_name(:key => orgname).first
          org && org["guid"]
        end

      end

      ORG_GUIDS_BY_NAME = OrgGuidMap.new

      def self.enable_org_guid_cache
        ORG_GUIDS_BY_NAME.enable_caching
      end

      def self.disable_org_guid_cache
        ORG_GUIDS_BY_NAME.disable_caching
      end

      def gen_cert(guid, rid=nil)
        Mixlib::Authorization::Log.debug "auth_helper.rb: certificate_service_uri is #{Mixlib::Authorization::Config.certificate_service_uri}"

        #common name is in the format of: "URI:http://opscode.com/GUIDS/...."
        common_name = "URI:http://opscode.com/GUIDS/#{guid}"

        response = JSON.parse(RestClient.post Mixlib::Authorization::Config.certificate_service_uri, :common_name => common_name)

        #certificate
        cert = OpenSSL::X509::Certificate.new(response["cert"])
        #private key
        key = OpenSSL::PKey::RSA.new(response["keypair"])
        [cert, key]
      rescue => e
        se_backtrace = e.backtrace.join("\n")
        Mixlib::Authorization::Log.error "Exception in gen_cert: #{e}\n#{se_backtrace}"
        raise Mixlib::Authorization::AuthorizationError, "Failed to generate cert: #{e}", e.backtrace
      end

      def orgname_to_dbname(orgname)
        (guid = guid_from_orgname(orgname)) && "chef_#{guid.downcase}"
      end

      def database_from_orgname(orgname)
        raise ArgumentError, "Must supply orgname" if orgname.nil? or orgname.empty?
        dbname = orgname_to_dbname(orgname)
        if dbname
          uri = Mixlib::Authorization::Config.couchdb_uri
          CouchRest.new(uri).database(dbname)
          CouchRest::Database.new(CouchRest::Server.new(uri),dbname)
        end
      end
      
      def guid_from_orgname(orgname)
        ORG_GUIDS_BY_NAME.guid_for_org(orgname)
      end 

      def user_to_actor(user_id)
        raise ArgumentError, "must supply user_id" unless user_id
        actor = AuthJoin.by_user_object_id(:key=>user_id).first
        Mixlib::Authorization::Log.debug("in user to actor: user: #{user_id}, actor:#{actor.inspect}")
        actor
      end

      def actor_to_user(actor, org_database)
        raise ArgumentError, "must supply actor" unless actor

        if Opscode::DarkLaunch.is_feature_enabled?('sql_users', :GLOBALLY)
          user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          if user = user_mapper.find_by_authz_id(actor)
            Mixlib::Authorization::Log.debug("actor to user: authz id: #{actor} is a user named #{user.username}")
          else
            begin
              client_join_entry = AuthJoin.by_auth_object_id(:key=>actor).first
              user = Mixlib::Authorization::Models::Client.on(org_database).get(client_join_entry.user_object_id)
              Mixlib::Authorization::Log.debug("actor to user: authz id: #{actor} is a client named #{user.clientname}")
            rescue StandardError=>se
              # BUGBUG: why rescue?
              Mixlib::Authorization::Log.error "Failed to turn actor #{actor} into a user or client: #{se}"
              nil
            end
          end
          user
        else
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
        if Opscode::DarkLaunch.is_feature_enabled?('sql_users', :GLOBALLY)
          user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          user = user_mapper.find_by_username(ucname)
        else
          user = Mixlib::Authorization::Models::User.by_username(:key => ucname).first
        end
        user ||= Mixlib::Authorization::Models::Client.on(org_database).by_clientname(:key=>ucname).first
        Mixlib::Authorization::Log.debug("user or client by name, name #{ucname}, org database, #{org_database}, user: #{user.class}, #{user.nil? ? nil : user.respond_to?(:username) ? user.username : user.clientname}")
        user
      end
      
      def transform_actor_ids(incoming_actors, org_database, direction)
        case direction
        when :to_user
          lookup_usernames_for_authz_ids(incoming_actors, org_database)
        when :to_auth
          lookup_authz_side_ids_for(incoming_actors, org_database)
        end
      end

      def lookup_usernames_for_authz_ids(actors, org_database)
        if Opscode::DarkLaunch.is_feature_enabled?('sql_users', :GLOBALLY)
          usernames = []
          # Find all the users in one query like a boss
          user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          users = user_mapper.find_all_by_authz_id(actors)
          remaining_actors = actors - users.map(&:authz_id)
          usernames.concat(users.map(&:username))
          Mixlib::Authorization::Log.debug { "Found #{users.size} users in actors list: #{actors.inspect} users: #{usernames}" }

          # 2*N requests to couch for the clients :(
          actor_names = remaining_actors.inject(usernames) do |clientnames, actor_id|
            if client = actor_to_user(actor_id, org_database)
              Mixlib::Authorization::Log.debug { "incoming_actor: #{actor_id} is a client named #{client.clientname}" }
              clientnames << client.clientname
            else
              Mixlib::Authorization::Log.debug { "incoming_actor: #{actor_id} is not a recognized user or client!" }
              clientnames
            end
          end
          Mixlib::Authorization::Log.debug { "Mapped actors #{actors.inspect} to users #{actor_names}" }
          actor_names

        else
          actors.inject([]) do |outgoing_actors, incoming_actor|
            actor = (user_or_client = actor_to_user(incoming_actor, org_database)) && ((user_or_client.respond_to?(:username) && user_or_client.username) || user_or_client.clientname )
            Mixlib::Authorization::Log.debug "incoming_actor: #{incoming_actor} is not a recognized user or client!" if actor.nil?
            (actor.nil? ? outgoing_actors : outgoing_actors << actor)
          end
        end
      end

      def lookup_authz_side_ids_for(actors, org_database)
        if Opscode::DarkLaunch.is_feature_enabled?('sql_users', :GLOBALLY)
          authz_ids = []
          #look up all the users with one query like a boss
          user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          users = user_mapper.find_all_for_authz_map(actors)
          authz_ids.concat(users.map(&:authz_id))
          actors -= users.map(&:username)

          # 2*N requests to couch for the clients :'(
          transformed_ids = actors.inject(authz_ids) do |client_authz_ids, clientname|
            if client = Mixlib::Authorization::Models::Client.on(org_database).by_clientname(:key=>clientname).first
              Mixlib::Authorization::Log.debug { "incoming actor: #{clientname} is a client with authz_id #{client.authz_id.inspect}" }
              client_authz_ids << client.authz_id
            else
              Mixlib::Authorization::Log.debug "incoming_actor: #{clientname} is not a recognized user or client!"
              client_authz_ids
            end
          end
          Mixlib::Authorization::Log.debug { "mapped actors: #{actors.inspect} to auth ids: #{transformed_ids.inspect}"}
          transformed_ids
        else
          actors.inject([]) do |outgoing_actors, incoming_actor|
            actor = (user = user_or_client_by_name(incoming_actor,org_database)) && user.authz_id
            Mixlib::Authorization::Log.debug "incoming_actor: #{incoming_actor} is not a recognized user or client!" if actor.nil?
            (actor.nil? ? outgoing_actors : outgoing_actors << actor)
          end
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

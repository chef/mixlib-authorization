#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#
require 'mixlib/authorization/authz_client'
require 'mixlib/authorization/auth_helper'
require 'mixlib/authorization/join_helper'
require 'mixlib/authorization/container_helper'
require 'mixlib/authorization/id_mapping_helper'

module Mixlib
  module Authorization
    class InvalidGroupMember < ArgumentError
    end

    module Models

      class AuthzIDMapper
        COUCH_ID = '_id'.freeze

        attr_reader :org_db
        attr_reader :user_mapper

        def initialize(org_db, user_mapper, clients_mapper=nil,clients_in_sql=false)
          @group_authz_ids_by_name = {}
          @group_names_by_authz_id = {}

          @actor_authz_ids_by_name = {}
          @actor_names_by_authz_id = {}

          @org_db = org_db
          @user_mapper = user_mapper
        end

        def actor_authz_ids_to_names(actor_ids)
          usernames = []
          Mixlib::Authorization::Log.debug { "Found #{users.size} users in actors list: #{actor_ids.inspect} users: #{usernames}" }

          users = users_by_authz_ids(actor_ids)
          remaining_actors = actor_ids - users.map(&:authz_id)

          usernames = users.map(&:username)
          # 2*N requests to couch for the clients :(
          actor_names = remaining_actors.inject(usernames) do |clientnames, actor_id|
            if clientname = client_authz_id_to_name(actor_id)
              clientnames << clientname
            else
              clientnames
            end
          end
          Mixlib::Authorization::Log.debug { "Mapped actors #{actors.inspect} to users #{actor_names}" }
          actor_names
        end

        def group_authz_ids_to_names(group_ids)
          group_ids.map {|group_id| group_authz_id_to_name(group_id)}.compact
        end

        def client_names_to_authz_ids(client_names)
          client_names.map do |clientname|
            unless client = Client.on(org_db).by_clientname(:key=>clientname).first
              raise InvalidGroupMember, "Client #{clientname} does not exist"
            end
            cache_actor_mapping(client.name, client.authz_id)
            client.authz_id
          end
        end

        def user_names_to_authz_ids(user_names)
          users = user_mapper.find_all_for_authz_map(user_names)
          unless users.size == user_names.size
            missing_user_names = user_names.select {|name| !users.any? {|user| user.name == name}}
            raise InvalidGroupMember, "Users #{missing_user_names.join(', ')} do not exist"
          end
          users.each {|u| cache_actor_mapping(u.name, u.authz_id) }
          users.map {|u| u.authz_id}
        end

        def group_names_to_authz_ids(group_names)
          group_names.map {|g| group_name_to_authz_id(g)}
        end

        private

        def cache_actor_mapping(name, authz_id)
          @actor_names_by_authz_id[authz_id] = name
          @actor_authz_ids_by_name[name] = authz_id
        end

        def cache_group_mapping(name, authz_id)
          @group_names_by_authz_id[authz_id] = name
          @group_authz_ids_by_name[name] = authz_id
        end

        def users_by_authz_ids(authz_ids)
          # Find all the users in one query like a boss
          users = @user_mapper.find_all_by_authz_id(authz_ids)
          users.each {|u| cache_actor_mapping(u.name, u.authz_id)}
          users
        end


        def client_authz_id_to_name(client_authz_id)
          if name = @actor_names_by_authz_id[client_authz_id]
            name
          elsif client_join_entry = AuthJoin.by_auth_object_id(:key=>client_authz_id).first
            client = Mixlib::Authorization::Models::Client.on(org_db).get(client_join_entry.user_object_id)
            cache_actor_mapping(client.name, client_authz_id)
            client.name
          else
            nil
          end
        end

        def group_name_to_authz_id(group_name)
          if authz_id = @group_authz_ids_by_name[group_name]
            authz_id
          elsif group = Group.on(org_db).by_groupname(:key=>group_name).first
            cache_group_mapping(group_name, group.authz_id)
            group.authz_id
          else
            raise InvalidGroupMember, "group #{group_name} does not exist"
          end
        end

        def group_authz_id_to_name(authz_id)
          if name = @group_names_by_authz_id[authz_id]
            name
          elsif auth_join = AuthJoin.by_auth_object_id(:key=>authz_id).first
            name = Mixlib::Authorization::Models::Group.on(org_db).get(auth_join.user_object_id).groupname
            cache_group_mapping(name, authz_id)
            name
          else
            nil
          end
        end
      end

      class Group < CouchRest::ExtendedDocument

        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        include Mixlib::Authorization::IDMappingHelper

        view_by :groupname
        view_by :orgname

        property :groupname
        property :orgname

        validates_present :groupname
        validates_present :orgname

        validates_format :groupname, :with => /^[a-z0-9\-_]+$/

        auto_validate!

        inherit_acl

        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Group

        join_properties :groupname, :actors, :groups, :requester_id

        COUCH_ID = "_id".freeze

        def initialize(attributes={})
          reset!

          @actor_and_group_names = {}

          @desired_actors = nil
          @desired_groups = nil

          actor_and_group_names = attributes.delete(:actor_and_group_names) || attributes.delete("actor_and_group_names") || {}

          super(attributes)

          # Le sigh. For global groups, we create a CouchRest db object based on the orgname
          # instead of using the actual database that this document belongs to.
          org_db = (orgname && database_from_orgname(orgname)) || database
          user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          @authz_id_mapper = AuthzIDMapper.new(org_db, user_mapper, nil, nil)

          # if this is an existing document, the object gets created with the
          # couch _id and _rev fields set. There may or may not be an
          # actor_and_group_names entry in the existing couch doc, but this
          # information is irrelevant, because authz is the cannonical source
          # of group membership information. In the case of an existing
          # document, we don't care to set the actor_and_group_names attribute.
          #
          # Also note, this must come after the call to super so that couchrest
          # will set the database attribute
          unless attributes.key?(COUCH_ID)
            self.actor_and_group_names = actor_and_group_names
          end
        end

        def requester_id
          self[:requester_id]
        end

        def authz_client
          @authz_client ||= AuthzClient.new(:groups, requester_id)
        end

        def reset!
          @authz_document = nil
          @actors = nil
          @groups = nil
        end

        def save
          was_a_new_doc = new_record?
          result = super
          if result && was_a_new_doc
            create_authz_object_as(requester_id)
            result = result && save_inherited_acl
            reconcile_memberships
          elsif result
            reconcile_memberships
            result = result && update_join
          end
          result
        end

        def actor_and_group_names=(new_actor_and_group_names)
          reset!
          @desired_actors, @desired_groups = transform_ids(new_actor_and_group_names)
          new_actor_and_group_names
        end

        def actor_and_group_names
          @actor_and_group_names
        end

        def add_actor(actor)
          reset!
          Mixlib::Authorization::Log.debug { "Adding actor: #{actor.inspect} to group #{self}"}
          if actor_id = actor.authz_id
            Mixlib::Authorization::Log.debug { "Found actor id #{actor_id} for #{actor}"}
          else
            raise "No actor id fround for #{actor.inspect}"
          end

          authz_client.resource(authz_id, :actors, actor_id).put(nil)
        end

        ACTORS = "actors".freeze

        def actors
          if @actors.nil?
            @actors = authz_document[ACTORS]
          end
          @actors
        end

        GROUPS = "groups".freeze

        def groups
          if @groups.nil?
            @groups = authz_document[GROUPS]
          end
          @groups
        end

        def for_json
          as_hash = {
            :actors => @authz_id_mapper.actor_authz_ids_to_names(actors),
            :groups => @authz_id_mapper.group_authz_ids_to_names(groups)
          }
          as_hash[:orgname] = orgname
          as_hash[:name] = groupname
          as_hash[:groupname] = groupname
          as_hash
        end

        private

        def reconcile_memberships
          insert_actors(@desired_actors - actors) if @desired_actors
          insert_groups(@desired_groups - groups) if @desired_groups

          delete_actors(actors - @desired_actors) if @desired_actors
          delete_groups(groups - @desired_groups) if @desired_groups
        end

        def insert_actors(actor_ids_to_add)
          actor_ids_to_add.each do |actor_id|
            resource = authz_client.resource(authz_id, :actors, actor_id)
            resource.put(nil)
          end
        end

        def insert_groups(group_ids_to_add)
          group_ids_to_add.each do |group_id|
            authz_client.resource(authz_id, :groups, group_id).put(nil)
          end
        end

        def delete_actors(actor_ids_to_remove)
          actor_ids_to_remove.each do |actor_id|
            authz_client.resource(authz_id, :actors, actor_id).delete
          end
        end

        def delete_groups(group_ids_to_remove)
          group_ids_to_remove.each do |group_id|
            authz_client.resource(authz_id, :groups, group_id).delete
          end
        end

        def transform_ids(actor_and_group_names)
          usernames  = actor_and_group_names["users"]    || []
          clientnames = actor_and_group_names["clients"]  || []
          groupnames  = actor_and_group_names["groups"]   || []

          user_ids = @authz_id_mapper.user_names_to_authz_ids(usernames)
          client_ids = @authz_id_mapper.client_names_to_authz_ids(clientnames)
          actor_ids = user_ids + client_ids

          group_ids = @authz_id_mapper.group_names_to_authz_ids(groupnames)

          [actor_ids, group_ids]
        end

        def authz_document
          @authz_document ||= fetch_join
        end

      end

    end
  end
end

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
require 'mixlib/authorization/authz_id_mapper'

module Mixlib
  module Authorization

    module Models

      ROWS = "rows"
      KEY = "key"

      # == ScopedGroup
      # Wraps up the access layers for the objects that groups interact with.
      # Since groups keep their cannonical data in authz where everything is
      # global, this has the effect of scoping groups to a particular
      # organization.
      #
      # Groups created/loaded via ScopedGroup get an AuthzIDMapper configured
      # with the right databases/mappers and Clients SQL migration status.
      #--
      # NB: The code here uses setter injection to set the AuthzIDMapper on the
      # Group objects, which I'd rather not do, but we don't have control of
      # the constructor for groups with couchrest :(
      class ScopedGroup
        attr_reader :group_db
        attr_reader :authz_id_mapper

        # Create a ScopedGroup
        # === Arguments
        # * group_db::: the CouchRest database this group should belong to
        # * org_db::: the CouchRest database this group's members belong to.
        #   For a global group, this is different than the group_db, otherwise
        #   it's the same.
        # * user_mapper::: An Opscode::Mappers::User object
        # * client_mapper::: NOT IMPLEMENTED YET
        # * clients_in_sql::: NOT IMPLEMENTED YET
        def initialize(group_db, org_db, user_mapper, client_mapper=nil, clients_in_sql=false)
          @group_db = group_db
          @org_db = @org_db
          @authz_id_mapper = AuthzIDMapper.new(org_db, user_mapper, client_mapper, clients_in_sql)
        end

        # Lists all of the groups (just names) in +group_db+
        def all
          Group.on(group_db).by_groupname(:include_docs => false)[ROWS].map {|g| g[KEY]}
        end

        # Find a group in +group_db+ by its name (aka groupname).
        def find_by_name(name)
          group = Group.on(group_db).by_groupname(:key => name).first
          group && group.database = group_db
          group && group.authz_id_mapper = authz_id_mapper
          group
        end

        # Create/initialize a new Group with the given attributes.
        def new(attrs={})
          actor_and_group_names = attrs.delete(:actor_and_group_names) || attrs.delete("actor_and_group_names")
          group = Group.on(group_db).new(attrs)
          group.database = group_db
          group.authz_id_mapper = authz_id_mapper
          group.actor_and_group_names = actor_and_group_names if actor_and_group_names
          group
        end
      end

      class Group < CouchRest::ExtendedDocument

        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        #include Mixlib::Authorization::IDMappingHelper

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

        attr_accessor :authz_id_mapper

        COUCH_ID = "_id".freeze

        def initialize(attributes={})
          # Remove deprecated user-side membership data--we rely exclusively on
          # authz for membership data now.
          attributes.delete(:actor_and_group_names) || attributes.delete("actor_and_group_names")
          reset!

          @actor_and_group_names = {}

          @desired_actors = nil
          @desired_groups = nil


          super(attributes)

          # Le sigh. For global groups, we create a CouchRest db object based on the orgname
          # instead of using the actual database that this document belongs to.
          #org_db = (orgname && database_from_orgname(orgname)) || database
          #user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
          #@authz_id_mapper = AuthzIDMapper.new(org_db, user_mapper, nil, nil)
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

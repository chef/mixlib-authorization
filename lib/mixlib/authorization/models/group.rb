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

        # This has to be a setter for ScopedGroup to correctly initialize a
        # Group. Not meant to be set anywhere else.
        attr_accessor :authz_id_mapper

        def initialize(attributes={})
          # Remove deprecated user-side membership data--we rely exclusively on
          # authz for membership data now.
          attributes.delete(:actor_and_group_names) || attributes.delete("actor_and_group_names")
          reset!

          @actor_and_group_names = {}

          @desired_actors = nil
          @desired_groups = nil

          super(attributes)
        end

        def requester_id
          self[:requester_id]
        end

        def authz_client
          @authz_client ||= AuthzClient.new(:groups, requester_id)
        end

        def reset!
          @authz_document  = nil
          @actor_authz_ids = nil
          @group_authz_ids = nil
          @client_names = nil
          @user_names   = nil
          @group_names  = nil
        end

        # Override CouchRest's #save so that we can also deal with creating the
        # authz side object (for creates) and add/remove group members from
        # authz as required (without callbacks b/c it's difficult to tell in
        # what order they occur and we have no means to pass arguments to them.
        #
        # On create, does:
        # * create user-side doc in couch
        # * create authz side object and authjoin
        # * inherit the ACL from the container and save it
        # * reconcile membership
        # On update:
        # * reconcile membership
        def save
          was_a_new_doc = new_record?
          result = super
          if result && was_a_new_doc
            create_authz_object_as(requester_id)
            result = result && save_inherited_acl
            reconcile_memberships
          elsif result
            reconcile_memberships
          end
          result
        end

        def actor_and_group_names=(new_actor_and_group_names)
          reset!
          @desired_actors, @desired_groups = translate_ids_to_authz(new_actor_and_group_names)
          new_actor_and_group_names
        end

        def actor_and_group_names
          @actor_and_group_names
        end

        # Provides a "backdoor" means to add an actor to a group without going
        # through a full GET-PUT cycle. Convenient because the other interface
        # to setting membership requires users and clients to be listed
        # separately, but Group provides no way to read the membership in that
        # format.
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

        # A backdoor to adding a group to this group without a full GET-PUT
        # cycle. See comments for #add_actor.
        def add_group(group)
          reset!
          unless group_authz_id = group.authz_id
            raise ArgumentError, "No actor id for group #{group.inspect}"
          end
          authz_client.resource(authz_id, :groups, group_authz_id).put(nil)
        end

        # A backdoor to deleting a group from this group without a GET-PUT
        # cycle. See comments for #add_actor
        def delete_group(group)
          reset!
          unless group_authz_id = group.authz_id
            raise ArgumentError, "No actor id for group #{group.inspect}"
          end
          authz_client.resource(authz_id, :groups, group_authz_id).delete
        end

        ACTORS = "actors".freeze

        def actor_authz_ids
          if @actor_authz_ids.nil?
            @actor_authz_ids = authz_document[ACTORS]
          end
          @actor_authz_ids
        end

        GROUPS = "groups".freeze

        def group_authz_ids
          if @group_authz_ids.nil?
            @group_authz_ids = authz_document[GROUPS]
          end
          @group_authz_ids
        end

        def client_names
          if @client_names.nil?
            translate_actors_to_user_side!
          end
          @client_names
        end

        def user_names
          if @user_names.nil?
            translate_actors_to_user_side!
          end
          @user_names
        end

        def actor_names
          client_names + user_names
        end

        def group_names
          @group_names ||= @authz_id_mapper.group_authz_ids_to_names(group_authz_ids)
        end

        def for_json
          as_hash = {
            :actors  => actor_names,
            :users   => user_names,
            :clients => client_names,
            :groups  => group_names
          }
          as_hash[:orgname] = orgname
          as_hash[:name] = groupname
          as_hash[:groupname] = groupname
          as_hash
        end

        private

        def translate_actors_to_user_side!
          actor_names = @authz_id_mapper.actor_authz_ids_to_names(actor_authz_ids)
          @user_names   = actor_names[:users]
          @client_names = actor_names[:clients]
          true
        end

        def reconcile_memberships
          insert_actors(@desired_actors - actor_authz_ids) if @desired_actors
          insert_groups(@desired_groups - group_authz_ids) if @desired_groups

          delete_actors(actor_authz_ids - @desired_actors) if @desired_actors
          delete_groups(group_authz_ids - @desired_groups) if @desired_groups
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

        def translate_ids_to_authz(actor_and_group_names)
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

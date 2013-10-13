# encoding: binary
# ^^ is needed for the email address regex to work properly
require 'openssl'
require 'digest/sha2'
require 'active_model'
require 'active_model/validations'

require 'opscode/models/base'

module Opscode
  module Models
    class InvalidParameters < ArgumentError
    end

    class Group < Base
      include ActiveModel::Validations

      use_authz_model_class(Opscode::AuthzModels::Group)

      # not sure if this should be a ro_attribute or a protected_attribute; renames aren't allowed
      rw_attribute :name
      alias :groupname :name

      protected_attribute :id
      protected_attribute :authz_id
      protected_attribute :org_id

      rw_attribute :last_updated_by
      alias :requester_id :last_updated_by

      # this exists because the API has the org name returned in for_json
      attr_accessor :org_name
      alias :orgname :org_name # old groups model didn't have a '_'
      # allow viewing of group actors and groups.
      attr_accessor :authz_id_mapper

      protected_attribute :created_at #custom reader method
      protected_attribute :updated_at #custom reader method

      validates_presence_of :name, :message => "must not be blank"
      validates_format_of   :name, :with => /\A([a-z0-9\-_])+\z/, :message => "has an invalid format"


      # Returns the class object that is used for the authz side representation
      # of this model. If not set, it will raise a NotImplementedError.
      def authz_model_class
        self.class.authz_model_class
      end

      def join_type
        Mixlib::Authorization::Models::JoinTypes::Group.new(Mixlib::Authorization::Config.authorization_service_uri,
                                                            "requester_id" => last_updated_by,
                                                            "object_id" => authz_id)
      end

      def fetch_join
        join_type.fetch
      end

      def authz_document
        @authz_document ||= fetch_join
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

      def translate_actors_to_user_side!
        actor_names = @authz_id_mapper.actor_authz_ids_to_names(actor_authz_ids)
        @user_names   = actor_names[:users]
        @client_names = actor_names[:clients]
        true
      end

      #
      #
      #

      def fetch_join_acl
        # may be mixing concerns here, since the other authz stuff
        # happens in the mapper...
        join_type.fetch_acl
      end

      def update_join_ace(type, data)
        join_type.update_ace(type,data)
      end

      def authz_client
        @authz_client ||= Mixlib::Authorization::AuthzClient.new(:groups, requester_id)
      end

      #
      # Brought over from authorization/models/group.rb
      # If we were planning to keep this code I'd refactor it, but...

      def reconcile_memberships
        insert_actors(@desired_actors - actor_authz_ids) if @desired_actors
        insert_groups(@desired_groups - group_authz_ids) if @desired_groups

        delete_actors(actor_authz_ids - @desired_actors) if @desired_actors
        delete_groups(group_authz_ids - @desired_groups) if @desired_groups
      end

      def insert_actors(actor_ids_to_add)
        actor_ids_to_add.each do |actor_id|
          resource = authz_client.resource(authz_id, :actors, actor_id)
          resource.put("")
        end
      end

      def insert_groups(group_ids_to_add)
        group_ids_to_add.each do |group_id|
          authz_client.resource(authz_id, :groups, group_id).put("")
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

      def actor_and_group_names=(new_actor_and_group_names)
#        reset!
        @desired_actors, @desired_groups = translate_ids_to_authz(new_actor_and_group_names)
        new_actor_and_group_names
      end

      def actor_and_group_names
        @actor_and_group_names
      end


      # Uses the direct add actor API in authz instead of going
      # through a full GET-PUT cycle. Convenient because the other interface
      # to setting membership requires users and clients to be listed
      # separately, but Group provides no way to read the membership in that
      # format.
      def add_actor(actor)
        Mixlib::Authorization::Log.debug { "Adding actor: #{actor.inspect} to group #{self}"}
        if actor_id = actor.authz_id
          Mixlib::Authorization::Log.debug { "Found actor id #{actor_id} for #{actor}"}
        else
          raise "No actor id found for #{actor.inspect}"
        end

        authz_client.resource(authz_id, :actors, actor_id).put("")
      end

      # A backdoor to adding a group to this group without a full GET-PUT
      # cycle. See comments for #add_actor.
      def add_group(group)
        unless group_authz_id = group.authz_id
          raise ArgumentError, "No actor id for group #{group.inspect}"
          end
        authz_client.resource(authz_id, :groups, group_authz_id).put("")
      end

      # A backdoor to deleting a group from this group without a GET-PUT
      # cycle. See comments for #add_actor
      def delete_group(group)
        unless group_authz_id = group.authz_id
          raise ArgumentError, "No actor id for group #{group.inspect}"
        end
        authz_client.resource(authz_id, :groups, group_authz_id).delete
      end


      # Assigns instance variables from "safe" params, that is ones that are
      # not defined via +protected_attribute+.
      #
      # This should be called by #initialize so you shouldn't have to call it
      # yourself. But if you do, user supplied input is ok.
      #
      # NB: This destructively modifies the argument, so dup before you call it.
      #
      # Also note, this overrides the implementation in Base.
      def assign_ivars_from_params!(params)
        params.each do |attr, value|
          if ivar = self.class.model_attributes[attr.to_s]
            instance_variable_set(ivar, params[attr])
          end
        end
      end

      # Setter for org_id. This is a protected attribute so we don't
      # accidentally allow users to change the org_id of a client.
      def assign_org_id!(new_org_id)
        @org_id = new_org_id
      end

      # These objects can't determine if their attrs
      # are globally unique or not, so the data layer calls this when a
      # uniqueness constraint is violated.
      def name_not_unique!
        errors.add(:conflicts, "name")
        errors.add(:name, "already exists.")
      end


      # overrides attr_reader to use custom reader in superclass
      def created_at
        super
      end

      # overrides attr_reader to use custom reader in superclass
      def updated_at
        super
      end

      # A Hash representation of this object suitable for conversion to JSON
      # for publishing via API. Protected attributes will not be included.
      def for_json
        hash_for_json = {
          "actors" => actor_names,
          "users" => user_names,
          "clients" => client_names,
          "groups" => group_names,
          "orgname"=>org_name,
          "name"=>name,
          "groupname"=>name
        }
      end


    end
  end
end

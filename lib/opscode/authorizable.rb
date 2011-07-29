require 'mixlib/authorization'
require 'mixlib/authorization/models/join_document'
require 'mixlib/authorization/models/join_types'

module Opscode

  module AuthzModels
    Actor = Mixlib::Authorization::Models::JoinTypes::Actor
  end

  # This mixin provides an adapter layer for Models to have a representation in
  # the Authorization service.
  #
  # Implementers of this mixin should define the following methods:
  # * authz_id => returns the authz_side id of the object if it exists, or nil
  # if it does not.
  # * authz_model_class => returns the class of authz model that represents the
  # authz side of this object. Currently, these are subclasses of
  # Mixlib::Authorization::Models::JoinDocument.
  # * assign_authz_id!("uuid") => sets the authorization side id. Called after
  # creating the authz side object. Must accept a nil argument to unset the id.
  module Authorizable

    OBJECT_ID = "object_id".freeze

    REQUESTER_ID = "requester_id".freeze

    def logger
      Mixlib::Authorization::Log
    end

    def call_info
      caller[0]
    end

    def authz_config
      Mixlib::Authorization::Config
    end

    # The information about this object that is required to create its AuthZ side counterpart.
    def authz_model_data_as(requesting_actor_id)
      { OBJECT_ID=>authz_id, REQUESTER_ID => requesting_actor_id}
    end

    # Returns the so called "AuthJoin" model document representing this
    # object. The requesting actor id is required for authz to authorize the
    # request.
    def authz_object_as(requesting_actor_id)
      authz_model_class.new(authz_config.authorization_service_uri, authz_model_data_as(requesting_actor_id))
    end

    # Creates the AuthZ side model for this object, acting as the actor (user/client)
    # specified by +requesting_actor_id+ (an AuthZ actor's id).
    def create_authz_object_as(requesting_actor_id)
      logger.debug { "#{call_info} saving #{authz_model_class} #{self.inspect}" }

      authz_model = authz_object_as(requesting_actor_id)
      authz_model.save
      logger.debug { "#{call_info} authz_model for #{self.class} (user id: #{id}) saved: #{authz_model.identity}" }

      assign_authz_id!(authz_model.identity["id"])
    end

    def update_authz_object_as(requesting_actor_id)
      logger.debug { "#{call_info} updating authz model #{authz_model_class} #{self.inspect}" }

      authz_model = authz_object_as(requesting_actor_id)
      authz_model.update

      logger.debug { "#{call_info} updated authz model #{authz_model.inspect}" }
    end

    # Destroys the AuthZ side model for this object, acting as the user/client
    # specified by +requesting_actor_id+ (an AuthZ side actor's id)
    #
    # NB: This doesn't actually destroy the authz side object, it just deletes
    # our reference to it. This is how it was in the previous CouchDB-based code.
    def destroy_authz_object_as(requesting_actor_id)
      if authz_id
        # The actual destroy was removed from the original couchdb-based
        # implementation at some point. We won't rock the boat by changing it.
        #authz_model = authz_object_as(requesting_actor_id)
        #logger.debug "#{call_info} removing reference to authz object: #{authz_model_class} #{authz_model}"
        #authz_model.delete
        #logger.debug "#{call_info}:destroyed authz model: #{authz_model.inspect}"
        assign_authz_id!(nil)
      else
        #logger.debug "IN DELETE JOIN ACL: Cannot find join for #{self.id}"
        false
      end
    end

    def authorized?(actor,ace)
      logger.debug { "IN IS_AUTHORIZED?: #{join_data.inspect}" }
      authz_model = authz_object_as(actor)
      logger.debug { "IN IS_AUTHORIZED? AUTH_JOIN OBJECT: #{authz_model.inspect}" }
      authz_model.is_authorized?(actor,ace)
    end

    alias :is_authorized? :authorized?

  end
end


#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'mixlib/authorization/authz_client'

module Mixlib
  module Authorization
    module Models
      class JoinDocument

        def self.authz_resource_name
          @authz_resource_name ||= name.split("::").last.downcase + "s"
        end

        def resource
          self.class.authz_resource_name
        end

        attr_reader :identity
        attr_reader :base_url
        attr_reader :model_data
        attr_reader :requester_id
        attr_reader :id

        alias :join_data :model_data

        ACL = "acl".freeze
        ACE = "ace".freeze
        ACTORS = "actors".freeze
        GROUPS = "groups".freeze
        OBJECT_ID = "object_id".freeze
        ID = "id"
        REQUESTER_ID = "requester_id".freeze

        # Create a new Authz side model.
        # === Arguments
        # * base_url::: The base URL for the authorization service
        # === Params +model_data+
        # * 'requester_id' ::: (mandatory) the authz id of the actor making the request
        # * 'object_id' ::: (omitted for create operations, required
        #   otherwise). The authz id of the object.
        def initialize(base_url,model_data)
          @base_url = base_url
          @model_data = model_data


          unless @requester_id = model_data[REQUESTER_ID]
            raise ArgumentError, "Cannot create a #{self.class} without a requester_id"
          end

          @authz_client = AuthzClient.new(resource, @requester_id, base_url)
          @id = model_data[OBJECT_ID]
        end

        def headers
          @headers ||= begin
            h = BASE_HEADERS.dup
            h[X_OPS_REQUESTING_ACTOR_ID] = requester_id
            h
          end
        end

        def save
          rest = resource_for()
          @identity = JSON.parse(rest.post(model_data.to_json))
          @id = @identity[ID]
          @identity
        end

        def fetch
          rest = resource_for(id)
          @identity  = JSON.parse(rest.get).merge({ "id"=>id })
          @identity
        end

        def update
        end

        def fetch_acl
          rest = resource_for(id, ACL)
          JSON.parse(rest.get)
        end

        def authorized?(actor, ace)
          rest = resource_for(id, ACL, ace, ACTORS, actor.to_s)
          JSON.parse(rest.get)
        rescue RestClient::ResourceNotFound
          false
        end

        # back compat. FYI, is_foo? is javaism
        alias :is_authorized? :authorized?

        #e.g. ace_name: 'delete', ace_data: {"actors"=>["signing_caller"], "groups"=>[]}
        def update_ace(ace_name, ace_data)
          Mixlib::Authorization::Log.debug "IN UPDATE ACE: #{self.inspect}, ace_data: #{ace_data.inspect}"

          # update actors and groups
          rest = resource_for(id, ACL, ace_name)
          current_ace = JSON.parse(rest.get)
          new_ace = Hash.new
          [ACTORS, GROUPS].each do |actor_type|
            if ace_data.has_key?(actor_type)
              to_delete = current_ace[actor_type] - ace_data[actor_type]
              to_put    = ace_data[actor_type] - current_ace[actor_type]
              new_ace[actor_type] = current_ace[actor_type] - to_delete + to_put
            end
          end

          Mixlib::Authorization::Log.debug("IN UPDATE ACE: Current ace: #{current_ace.inspect}, Future ace: #{new_ace.inspect}")

          rest = resource_for(id, ACL, ace_name)
          resp = JSON.parse(rest.put(new_ace.to_json))

          Mixlib::Authorization::Log.debug("IN UPDATE ACE: response #{resp.inspect}")
          resp
        rescue => se
          Mixlib::Authorization::Log.error "Failed to update ace: #{se.message} " + se.backtrace.join(",\n")
          raise
        end

        def delete
          rest = resource_for(id)
          resp = JSON.parse(rest.delete)

          @identity = resp
          true
        end

        # Merges the ACL of the given +container+ on to this object's ACL.
        # +container+ should be the *AuthZ side* container object, not the user-side.
        def apply_parent_acl(container)
          container_acl_data = container.fetch_acl
          container_acl = Acl.new(container_acl_data)
          self_acl = Acl.new(fetch_acl)
          self_acl.merge!(container_acl)
          self_acl.aces.each {  |ace_name,ace| update_ace(ace_name, ace.ace) }
        end

        # Adds the actor given by +actor_id+ (an authz side id) to the
        # specified ace for this object.
        # Ex:
        #   grant_permission_to_actor("read", client.authz_id)
        #
        def grant_permission_to_actor(ace_type, actor_id)
          self_acl = Acl.new(fetch_acl)
          target_ace = self_acl.aces[ace_type]
          target_ace.add_actor(actor_id)
          update_ace(ace_type, target_ace.ace)
        end

        # Create a RestClient::Resource for the given path components. See also AuthzClient
        def resource_for(*paths)
          @authz_client.resource(*paths)
        end

      end
    end
  end
end

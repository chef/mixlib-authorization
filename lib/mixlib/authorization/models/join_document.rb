#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

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

        BASE_HEADERS = {:accept         => "application/json".freeze,
                        :content_type   => "application/json".freeze,
                        "X-Ops-User-Id".freeze => 'front-end-service'.freeze }.freeze

        X_OPS_REQUESTING_ACTOR_ID = "X-Ops-Requesting-Actor-Id".freeze
        REQUESTER_ID = "requester_id".freeze

        FSLASH = "/".freeze

        ACL = "acl".freeze
        ACE = "ace".freeze
        ACTORS = "actors".freeze
        GROUPS = "groups".freeze
        OBJECT_ID = "object_id".freeze
        ID = "id"

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
          Mixlib::Authorization::Log.debug "IN SAVE: model_data #{model_data.inspect}"
          rest = resource_for()
          @identity = JSON.parse(rest.post(model_data.to_json))
          @id = @identity[ID]
          Mixlib::Authorization::Log.debug "IN SAVE: response: #{@identity.inspect}"
          @identity
        end

        def fetch
          Mixlib::Authorization::Log.debug "IN FETCH: #{self.inspect}"

          rest = resource_for(id)
          @identity  = JSON.parse(rest.get).merge({ "id"=>id })
          Mixlib::Authorization::Log.debug "IN FETCH: response #{@identity.inspect}"
          @identity
        end

        def update
          Mixlib::Authorization::Log.debug "IN UPDATE: #{self.inspect}"
        end

        def fetch_acl
          Mixlib::Authorization::Log.debug "IN FETCH ACL: #{self.inspect}"

          rest = resource_for(id, ACL)
          @identity  = JSON.parse(rest.get)

          Mixlib::Authorization::Log.debug "FETCH ACL: #{@identity.inspect}"
          @identity
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

        # Create a RestClient::Resource for the given path components. See also: #url_for
        def resource_for(*paths)
          RestClient::Resource.new(url_for(*paths),:headers=>headers, :timeout=>5, :open_timeout=>1)
        end

        # Generate the URL for the given path components. If no components are
        # given, it returns the base URL for the resource type (e.g., http://authz:2345/clients)
        def url_for(*paths)
          paths.inject("#{base_url}/#{resource}") {|url, component| url << FSLASH << component.to_s}
        end

      end
    end
  end
end

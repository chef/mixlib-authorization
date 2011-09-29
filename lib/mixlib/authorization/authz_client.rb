require 'restclient'

module Mixlib
  module Authorization

    # Client for "raw" http access to authz. AuthzClient objects don't actually
    # make the requests, they just generate RestClient resources with all the
    # header and content type bits set correctly for talking to authz.
    class AuthzClient
      BASE_HEADERS = {:accept         => "application/json".freeze,
                      :content_type   => "application/json".freeze,
                      "X-Ops-User-Id".freeze => 'front-end-service'.freeze }.freeze

      X_OPS_REQUESTING_ACTOR_ID = "X-Ops-Requesting-Actor-Id".freeze
      REQUESTER_ID = "requester_id".freeze

      FSLASH = "/".freeze

      attr_reader :authz_uri
      attr_reader :resource_name
      attr_reader :requester_id

      # Create a client for the authorization service.
      # === Arguments
      # resource_name::: the (plural) *name* of this resource, e.g., :groups, :actors, etc.
      # requester_id::: the authz id of the actor making the request
      # authz_uri::: URI of the authz service, defaults to Config.authorization_service_uri
      def initialize(resource_name, requester_id, authz_uri=nil)
        @resource_name  = resource_name
        @requester_id   = requester_id
        @authz_uri      = authz_uri || Config.authorization_service_uri
      end

      # Create a RestClient::Resource for the given path components. See also: #url_for
      def resource(*paths)
        RestClient::Resource.new(url_for(*paths),:headers=>headers, :timeout=>5, :open_timeout=>1)
      end

      # Headers sent to authz with each request.
      def headers
        @headers ||= begin
          h = BASE_HEADERS.dup
          h[X_OPS_REQUESTING_ACTOR_ID] = requester_id
          h
        end
      end

      # Generate the URL for the given path components. If no components are
      # given, it returns the base URL for the resource type (e.g., http://authz:2345/clients)
      def url_for(*paths)
        paths.inject("#{authz_uri}/#{resource_name}") {|url, component| url << FSLASH << component.to_s}
      end

    end

  end
end

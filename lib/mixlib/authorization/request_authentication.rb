#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'time'
require 'mixlib/authorization'
require 'mixlib/authentication/signatureverification'
require 'mixlib/authorization/models'
require 'pp'
require 'stringio'
require 'opscode/dark_launch'
require 'opscode/models/user'
require 'opscode/mappers/user'

module Mixlib
  module Authorization
    class RequestAuthentication
      include AuthHelper

      def self.authenticate_every(*args)
        raise Exception, "this method is gone away. create an object and call #valid_request? on it."
        new(request, params, web_ui_public_key).authenticate
      end

      attr_reader :request

      attr_reader :params

      attr_reader :authenticator

      attr_reader :missing_headers

      attr_reader :actor_type

      def initialize(request, params)
        @request, @params = request, params
        create_authenticator
      end

      def authenticate
        raise Exception, "THIS METHOD IS DONE FOR. USE #valid_request? instead"
      end

      def valid_request?
        # TODO: This takes less time for an invalid username than it does for
        # an incorrect key. [dan]
        required_headers_present? && requesting_entity_exists? && actor_exists? && authentic_request?
      end

      def headers
        @authenticator.headers
      end

      def username
        @authenticator.user_id
      end

      def orgname
        #BUGBUG - next line seems odd.  Can't we ensure that it's *always* :organization_id? [cb]
        @orgname ||= (params[:organization_id] || params[:id])
      end

      def required_headers_present?
        !@missing_headers
      end

      def requesting_entity
        @requesting_entity ||= begin
          (find_user || find_client) or raise AuthorizationError, "Cannot find user or client #{username} in org #{orgname}"
        end
      end

      def requesting_entity_exists?
        !!requesting_entity
      rescue AuthorizationError => e
        Log.debug("Error loading requesting entity: #{e}")
        false
      end

      def request_from_validator?
        (requesting_entity.respond_to?(:validator?) && requesting_entity.validator?) || false
      end

      def request_from_webui?
        headers[:x_ops_request_source] == 'web'
      end

      def requesting_actor_id
        @requesting_actor_id ||= actor
      end

      def actor
        @actor ||= requesting_entity.authz_id
      end

      def actor_exists?
        !!actor
      end

      def append_auth_info_to_params!
        raise Exception, "this method is gone, and we shouldn't have depended on this behavior being in this class in the first place."
      end

      def user_key
        @user_key ||= begin
          key_text = request_from_webui? ? webui_public_key : requesting_entity.public_key
          OpenSSL::PKey::RSA.new(key_text)
        end
      end

      def authentic_request?
        authenticator.authenticate_request(user_key)
      rescue StandardError => se
        Log.debug "Authentication failed: #{se}, #{se.backtrace.join("\n")}"
        false
      end

      def valid_timestamp?
        # BUG/TODO: this can only be called after #authentic_request? is called :(
        @authenticator.valid_timestamp?
      end

      private

      def webui_public_key
        Config[:web_ui_public_key]
      end

      def find_user
        Log.debug "Authentication: trying to find user: #{username}"
        if Opscode::DarkLaunch.is_feature_enabled?('sql_users', :GLOBALLY)
          find_user_sql
        else
          find_user_couchdb
        end
      end

      def find_user_couchdb
        user = Models::User.find(username)
        @actor_type = :user
        user
      rescue ArgumentError
        Log.debug "No user found for username: #{username}"
        nil
      end

      def find_user_sql
        user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection,nil, 0)
        if user = user_mapper.find_for_authentication(username)
          Log.debug("Found user for #{username}")
          @actor_type = :user
          user
        else
          Log.debug "No user found for username: #{username}"
          nil
        end
      end

      def find_client
        if orgname && (db = database_from_orgname(orgname))
          Log.debug "checking for client #{username}"
          client = Models::Client.on(db).by_clientname(:key=>username).first
          Log.debug "Found client for #{username}"
          @actor_type = :client
          client
        else
          Log.debug "No database found for organization #{orgname}"
          nil
        end
      rescue ArgumentError
        Log.debug "No client found for client name: #{username} in organization: #{orgname}"
        nil
      end

      def create_authenticator
        @authenticator = Mixlib::Authentication::SignatureVerification.new(request)
        @missing_headers = nil
        debug_headers
      rescue Mixlib::Authentication::MissingAuthenticationHeader => e
        Log.debug "Request is missing required headers for authentication"
        Log.debug(e)
        @authenticator = nil
        @missing_headers = e.message
      end

      def debug_headers
        if Log.debug?
          debug_msg = StringIO.new
          PP.pp({"Raw request headers" => headers}, debug_msg)
          Log.debug(debug_msg.string)
        end
        Log.debug "Authenticating username #{username}, orgname #{orgname}"
      end


    end
  end
end

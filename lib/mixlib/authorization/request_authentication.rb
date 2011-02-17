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

      def initialize(request, params)
        @request, @params = request, params
        @user = nil
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
        @orgname ||= params[:organization_id] #|| params[:id])
      end

      def required_headers_present?
        !@missing_headers
      end

      def requesting_entity
        @requesting_entity ||= begin
          (find_user || find_client) #or raise AuthorizationError, "Cannot find user or client #{username} in org #{orgname}"
        end
      end

      def requesting_entity_exists?
        !!requesting_entity
      rescue AuthorizationError => e
        Log.debug "Cannot find a user or client for username/clientname #{username}"
        Log.debug e
        false
      end

      def request_from_validator?
        (requesting_entity.respond_to?(:validator?) && requesting_entity.validator?) || false
      end

      def request_from_webui?
        headers[:x_ops_request_source] == 'web'
      end

      def requesting_actor_id
        @requesting_actor_id ||= actor && actor.auth_object_id
      end

      def actor
        @actor ||= user_to_actor(requesting_entity.id)
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

      def org_db
        @org_db ||= database_from_orgname(orgname)
      end

      def org
        @org ||= Models::Organization.by_name(:key => orgname).first
      end

      def org_id
        @org_id ||= begin
          org && org.id
        end
      end

      def authentic_request?
        authenticator.authenticate_request(user_key)
      rescue StandardError => se
        Chef::Log.debug "Authentication failed: #{se}, #{se.backtrace.join("\n")}"
        false
      end

      def valid_timestamp?
        # BUG/TODO: this can only be called after #authentic_request? is called :(
        @authenticator.valid_timestamp?
      end

      # Determines if the actor for this request is associated with this organization
      # When the requesting_entity is a Client, this is always true, b/c clients are
      # scoped by org.
      # When the requesting_entity is a User, this will check if we have an
      # OrganizationUser document joining the user and org.
      def valid_actor_for_org?
        # BUG/TODO: relying on the side effect of requesting_entity setting
        # @user is fugly [love, dan]
        if requesting_entity && Models::Client === requesting_entity
          true
        elsif @user
          valid_user_for_org?
        else
          # shouldn't get here.
          nil
        end
      end

      private

      def org_ids_for(user)
        @org_ids ||= Models::OrganizationUser.organizations_for_user(user)
      end

      def valid_user_for_org?
        return true unless orgname
        if (org && org_ids_for(@user).include?(org_id))
          true
        else
          Log.debug "Org IDs for user are #{org_ids_for(@user)}, expected #{org_id}"
          false
        end
      end

      def webui_public_key
        Config[:web_ui_public_key]
      end

      def find_user
        Log.debug "checking for user #{username}"
        @user = Models::User.find(username)
        valid_user_for_org? && @user
      rescue ArgumentError
        Log.debug "No user found for username: #{username}"
        nil
      end

      def find_client
        if orgname && org_db
          Log.debug "checking for client #{username}"
          Models::Client.on(org_db).by_clientname(:key=>username).first
        else
          Log.debug "No database found for organization '#{orgname}'"
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

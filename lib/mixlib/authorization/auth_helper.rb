#
# Author:: Nuo Yan <nuo@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'openssl'
require 'rest_client'

module Mixlib
  module Authorization
    class DeadCode < Exception
    end


    module AuthHelper

      class OrgGuidMap
        def initialize
          @cached_map = {}
          @caching = false
        end

        def enable_caching
          @caching = true
        end

        def disable_caching
          @caching = false
        end

        def guid_for_org(orgname)
          @caching ? lookup_with_caching(orgname) : lookup_without_caching(orgname)
        end

        private

        def lookup_with_caching(orgname)
          if guid = @cached_map[orgname]
            guid
          else
            @cached_map[orgname] = lookup_without_caching(orgname)
          end
        end

        def lookup_without_caching(orgname)
          org = Mixlib::Authorization::Models::Organization.by_name(:key => orgname).first
          org && org["guid"]
        end

      end

      ORG_GUIDS_BY_NAME = OrgGuidMap.new

      def self.enable_org_guid_cache
        ORG_GUIDS_BY_NAME.enable_caching
      end

      def self.disable_org_guid_cache
        ORG_GUIDS_BY_NAME.disable_caching
      end

      def gen_cert(guid, rid=nil)
        Mixlib::Authorization::Log.debug "auth_helper.rb: certificate_service_uri is #{Mixlib::Authorization::Config.certificate_service_uri}"

        #common name is in the format of: "URI:http://opscode.com/GUIDS/...."
        common_name = "URI:http://opscode.com/GUIDS/#{guid}"

        response = JSON.parse(RestClient.post Mixlib::Authorization::Config.certificate_service_uri, :common_name => common_name)

        #certificate
        cert = OpenSSL::X509::Certificate.new(response["cert"])
        #private key
        key = OpenSSL::PKey::RSA.new(response["keypair"])
        [cert, key]
      rescue => e
        se_backtrace = e.backtrace.join("\n")
        Mixlib::Authorization::Log.error "Exception in gen_cert: #{e}\n#{se_backtrace}"
        raise Mixlib::Authorization::AuthorizationError, "Failed to generate cert: #{e}", e.backtrace
      end

      def orgname_to_dbname(orgname)
        (guid = guid_from_orgname(orgname)) && "chef_#{guid.downcase}"
      end

      def database_from_orgname(orgname)
        raise ArgumentError, "Must supply orgname" if orgname.nil? or orgname.empty?
        dbname = orgname_to_dbname(orgname)
        if dbname
          uri = Mixlib::Authorization::Config.couchdb_uri
          CouchRest.new(uri).database(dbname)
          CouchRest::Database.new(CouchRest::Server.new(uri),dbname)
        end
      end

      def guid_from_orgname(orgname)
        ORG_GUIDS_BY_NAME.guid_for_org(orgname)
      end

      def check_rights(params)
        raise ArgumentError, "bad arg to check_rights" unless params.respond_to?(:has_key?)
        Mixlib::Authorization::Log.debug("check rights params: #{params.inspect}")
        params[:object].is_authorized?(params[:actor],params[:ace].to_s)
      end

      def get_global_admins_groupname(orgname)
        "#{orgname}_global_admins"
      end

      # /!\ DEAD CODES /!\
      # According to git grep and feature tests, these methods are only used by
      # the Group and ACL Classes. There's no need to include them in every
      # object, so they're moved to a separate module.
      #
      # However, there's a chance that some random script is using these and
      # we'd like to have helpful error messages for that case.

      DEAD_METHODS = [:user_to_actor, :user_or_client_by_name]
      MOVED_METHODS = [:actor_to_user, :auth_group_to_user_group, :user_group_to_auth_group,
                       :transform_actor_ids, :lookup_usernames_for_authz_ids,
                       :lookup_authz_side_ids_for, :transform_group_ids]

      def method_missing(method_name, *args, &block)
        if DEAD_METHODS.include?(method_name)
          raise DeadCode, "The method #{method_name} has been removed from AuthHelper with no replacement."
        elsif MOVED_METHODS.include?(method_name)
          raise DeadCode, "The method #{method_name} has been moved to IDMappingHelper"
        else
          super
        end
      end

    end

  end
end

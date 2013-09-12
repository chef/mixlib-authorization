#
# Author:: Adam Jacob <adam@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'mixlib/authorization/default_organization_policy'

module Mixlib
  module Authorization
    module Models
      class OrganizationNotFound < ArgumentError
      end

      class InvalidOrganization < ArgumentError
        attr_reader :errors
        def initialize(errors)
          super(errors.full_messages.join(", "))
          @errors = errors
        end
      end

      class NoUnassignedOrgsAvailable < RuntimeError
      end

      class Organization < CouchRest::ExtendedDocument
        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper

        use_database Mixlib::Authorization::Config.default_database

        view_by :name
        view_by :full_name
        view_by :org_type
        view_by :guid

        property :name
        property :full_name
        property :org_type
        property :clientname
        property :guid
        property :chargify_subscription_id
        property :chargify_customer_id
        property :billing_plan
        property :assigned_at, :cast_as => Time

        validates_present :name, :full_name, :clientname

        validates_with_method :name, :unique_name?

        validates_format :name, :with => /^[a-z0-9_-]*$/, :message => "name must only contain letters, digits, hyphens, and underscores"
        validates_format :name, :with => /^[a-z0-9]/, :message => "name must begin with a letter or digit"

        auto_validate!

        create_callback :after, :create_join
        update_callback :after, :update_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Object
        join_properties :requester_id

        def self.create_from_unassigned(params)
          test_org = new(params)
          unless test_org.valid?
            raise InvalidOrganization, test_org.errors
          end
          if available_org = Mixlib::Authorization::Models::OrganizationInternal.select_available_org
            original_name = available_org.name
            available_org.name            = params[:name]
            available_org.org_type        = params[:org_type]
            available_org.full_name       = params[:full_name]
            available_org.clientname      = params[:clientname]
            available_org[:requester_id]  = params[:requesting_actor_id]
            available_org.assigned_at     = Time.now.utc
            available_org.save
          else
            raise NoUnassignedOrgsAvailable, "no unassigned orgs available"
          end
          return [original_name, available_org]
        end

        def unique_name?
          r = Organization.by_name(:key => self["name"], :include_docs => false)
          how_many = r["rows"].length
          # If we don't have an object with this name, then we are the first, and it's cool.
          # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
          if how_many == 0 || (how_many == 1 && self.has_key?('_id'))
            true
          else
            [ false, "The name #{self["name"]} is not unique!" ]
          end
        end

        def self.find(name)
          Organization.by_name(:key => name).first || raise(OrganizationNotFound, "Could not find organization named '#{name}'")
        end

        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]
            result[pname] = self.send(pname) unless pname == :requester_id
            result
          end
        end

        def org_db
          @org_db ||= database_from_orgname(name)
        end

        # Sets up a new organization
        def setup!(user_mapper, requesting_actor_id, options=Hash.new)
          create_database!

          policy = OrgAuthPolicy.new(self, user_mapper, requesting_actor_id)
          policy.apply!

          # Environments are in erchef / SQL. Make an HTTP request to create the default environment
          headers = {:headers => {'x-ops-request-source' => 'web'}}
          rest = Chef::REST.new(Chef::Config[:chef_server_host_uri],
                                Chef::Config[:web_ui_proxy_user],
                                Chef::Config[:web_ui_private_key], headers)
          rest.post_rest("organizations/#{name}/environments",
                        {
                           'name' => '_default',
                           'description' => 'The default Chef environment'
                         })
        end

        def create_database!
          # Create the chef-specific design documents
          cdb = Chef::CouchDB.new("http://#{Mixlib::Authorization::Config.couchdb_uri}", orgname_to_dbname(name))
          cdb.create_db(false)
          cdb.create_id_map
        end
      end
    end
  end
end

#
# Author:: Adam Jacob <adam@opscode.com>
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#
module Mixlib
  module Authorization
    module Models
      class OrganizationUser < CouchRest::ExtendedDocument
        include CouchRest::Validation

        use_database Mixlib::Authorization::Config.default_database

        view_by :organization
        view_by :user

        property :role
        property :organization
        property :user

        validates_present :organization, :user

        view_by :users_for_organization, 
          :map => "function(doc) {
                     if (doc['couchrest-type'] == 'Mixlib::Authorization::Models::OrganizationUser') {
                       emit(doc.organization,doc.user);
                     }
                   }"

        view_by :organizations_for_user, 
          :map => "function(doc) {
                     if (doc['couchrest-type'] == 'Mixlib::Authorization::Models::OrganizationUser') {
                       emit(doc.user,doc.organization);
                     }
                  }"

        view_by :organization_user,
          :map => "function(doc) {
                     if (doc['couchrest-type'] == 'Mixlib::Authorization::Models::OrganizationUser') {
                       emit([doc.organization,doc.user],null);
                     }
                  }"

        save_callback :before, :deflate

        def deflate
          self.organization = self.organization.id if self.organization.kind_of?(Mixlib::Authorization::Models::Organization)
          self.user = self.user.id if self.user.kind_of?(Mixlib::Authorization::Models::User)
          self
        end

        def inflate!
          self.organization = Mixlib::Authorization::Models::Organization.get(self.organization) unless self.organization.kind_of?(Mixlib::Authorization::Models::Organization)
          self.user = Mixlib::Authorization::Models::User.get(self.user) unless self.user.kind_of?(User)
          self
        end

        def self.find_by_org(org_oid)
          OrganizationUser.by_organization(:key => org_oid).first or raise ArgumentError
        end

        def self.find_by_user(user_id)
          OrganizationUser.by_user(:key => user_id).first or raise ArgumentError    
        end

        def self.users_for_organization(organization)
          org_id = organization.kind_of?(Mixlib::Authorization::Models::Organization) ? organization.id : organization
          by_users_for_organization(:startkey => org_id, :endkey => org_id, :include_docs => false)["rows"].map { |r| r["value"] }
      #    self.database.documents(:keys => users, :include_docs => true)["rows"].inject({}) { |users,doc| users[doc["name"]] = d["doc"]; users }
        end

        def self.organizations_for_user(user)
          user_id = user.kind_of?(Mixlib::Authorization::Models::User) ? user.id : user
          by_organizations_for_user(:startkey => user_id, :endkey => user_id, :include_docs => false)["rows"].map {|r| r["value"] }
        end 

        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            result[pname] = self.send(pname)
            result
          end
        end

      end
    end
  end
end

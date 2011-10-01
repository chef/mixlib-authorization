#
# Author:: Tim Hinderliter <tim@opscode.com>
#
# Copyright 2010, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

class Array
  unless [].respond_to?(:choice)
    def choice
      sample
    end
  end
end

module Mixlib
  module Authorization
    module Models
      class OrganizationInternal < CouchRest::ExtendedDocument
        include CouchRest::Validation

        use_database Mixlib::Authorization::Config.internal_database

        view_by :state
        view_by :organization_guid
        view_by :state_count,
          :map =>
            "function(doc) {
              if (doc['couchrest-type'] == 'Mixlib::Authorization::Models::OrganizationInternal') {
                emit(doc.state, 1);
              };
            }",
          :reduce =>
            "function(keys, values, rereduce) {
              return sum(values);
            }"

        property :organization_guid
        property :state

        validates_present :organization_guid

        # TODO: timh: should validate with :valid_organization_guid?, and check to
        # ensure the organization exists in opscode_account
        validates_with_method :organization_guid, :unique_organization_guid?

        auto_validate!

        def self.select_available_org
          # As long as we're getting results back from find_unassigned_organization
          # keep trying to assign an existing organization
          picked_org_int = nil
          try_again = true
          num_tries = 0
          max_tries = 20

          while try_again
            try_again = false

            Mixlib::Authorization::Log.debug("finding unassigned organization attempt #{num_tries}/#{max_tries}")
            unless unassigned_org = find_unassigned_organization
              return false
            end

            Mixlib::Authorization::Log.debug "found unassigned org #{unassigned_org}, assigning..."

            begin
              # This may cause a ResourceNotFound, if another process got there first.
              unassigned_org.make_assigned
              return Mixlib::Authorization::Models::Organization.by_guid(:key => unassigned_org.organization_guid).first
            rescue RestClient::ResourceNotFound => e
              # Our call to make_assigned failed, as another process beat us to it; try again.
              Mixlib::Authorization::Log.debug "Conflict trying to assign unassigned org trying again"
              try_again = true
            end

            num_tries += 1

            # Bomb out if we hit out maximum retry limit.
            if num_tries >= max_tries
              return false
            end
          end

        end

        def self.find_unassigned_organization
          available_orgs = by_state(:key=>'unassigned')
          Mixlib::Authorization::Log.debug "find_unassigned_organization: by_organization_guid returned #{available_orgs.inspect}"

          if !available_orgs.empty?
            # From the list of unassigned orgs, return a random one.
            selected_org = available_orgs.choice
            Mixlib::Authorization::Log.debug "find_unassigned_organization: returning #{selected_org}"
            selected_org
          else
            Mixlib::Authorization::Log.debug "find_unassigned_organization: returning NOTHING, no unassigned organizations"
            nil
          end
        end

        def unique_organization_guid?
          result = OrganizationInternal.by_organization_guid(:key => self["organization_guid"], :include_docs => false)
          how_many = result["rows"].length

          if (how_many == 0) || (how_many == 1 && self['_id'] == result["rows"].first["id"])
            true
          else
            [ false, "The organization guid #{self['organization_guid']} is not unique!" ]
          end
        end

        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]
            result[pname] = self.send(pname) unless pname == :requester_id
            result
          end
        end

        # make the given organization unassigned - this is done when the temporary
        # organization is done being generated by opscode-org-creator.
        def make_unassigned
          self[:state]= 'unassigned'
          save
        end

        def make_started
          self[:state]='started'
          save
        end

        # make the given organization assigned - this is done once the organization
        # has been handed off to a real organization.
        def make_assigned
          destroy
        end

      end
    end
  end
end

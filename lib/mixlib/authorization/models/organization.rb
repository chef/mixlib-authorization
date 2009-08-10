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
      class Organization < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        
        unique_id :gen_guid
        use_database Mixlib::Authorization::Config.default_database
        
        view_by :name
        view_by :full_name
        view_by :org_type
        
        property :name
        property :full_name
        property :org_type
        property :clientname
        
        validates_present :name, :full_name, :org_type, :clientname
        
        validates_with_method :name, :unique_name?
        validates_with_method :org_type, :valid_org_types?
        validates_format :name, :with => /^[a-z0-9-]+$/

        auto_validate!

        save_callback :after, :create_join
        destroy_callback :before, :delete_join
        
        join_type Mixlib::Authorization::Models::JoinTypes::Object 
        join_properties :requester_id
        
        def valid_org_types?
          org_types = %w{Business Non-Profit Personal}
          
          if org_types.include?(self[:org_type])
            true
          else
            [ false, "Org type must be one of: #{org_types.join(", ")}" ]
          end
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
          Organization.by_name(:key => name).first or raise ArgumentError
        end
        
        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]      
            result[pname] = self.send(pname) unless pname == :requester_id
            result
          end
        end
        
      end
    end
  end
end

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
      class Node < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        
        use_database Mixlib::Authorization::Config.default_database
        
        view_by :name
        
        property :name
        
        validates_present :name
        
        validates_with_method :name, :unique_name?

        auto_validate!
        
        create_callback :after, :save_inherited_acl, :create_join
        update_callback :after, :update_join
        destroy_callback :before, :delete_join
        
        join_type Mixlib::Authorization::Models::JoinTypes::Object 
        join_properties :requester_id
        
        def unique_name?
          r = Node.by_name(:key => self["name"], :include_docs => false)
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
          Mixlib::Authorization::Models::Node.by_name(:key => name).first or raise ArgumentError
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

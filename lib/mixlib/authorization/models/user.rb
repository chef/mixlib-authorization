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
      class User < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        
        use_database Mixlib::Authorization::Config.default_database
        
        view_by :first_name
        view_by :last_name
        view_by :middle_name
        view_by :display_name
        view_by :email 
        view_by :name

        property :first_name
        property :last_name
        property :middle_name
        property :display_name
        property :email
        property :name
        property :public_key
        
        validates_with_method :name, :unique_username?

        validates_present :first_name, :last_name, :display_name, :name, :email, :public_key

        validates_format :name, :with => /^[a-z0-9\-_]+$/
        validates_format :email, :as => :email_address
        
        auto_validate!

        save_callback :after, :create_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor

        join_properties :requester_id

        def unique_username?
          begin
            r = User.by_name(:key => self["name"], :include_docs => false)
            how_many = r["rows"].length
            # If we don't have an object with this name, then we are the first, and it's cool.
            # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
            return true if (how_many == 0) || (how_many == 1 && self.has_key?('_id'))
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to determine if username '#{self['name']}' is unique"
          end
          [ false, "The name #{self["name"]} is not unique!" ]      
        end
        
        def self.find(name)
          User.by_name(:key => name).first or raise ArgumentError
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

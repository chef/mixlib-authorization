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
        
        unique_id :gen_guid
        use_database Mixlib::Authorization::Models::DEFAULT_DATABASE
        
        view_by :first_name
        view_by :last_name
        view_by :middle_name
        view_by :display_name
        view_by :email 
        view_by :username

        property :first_name
        property :last_name
        property :middle_name
        property :display_name
        property :email
        property :username
        property :public_key
        property :cert_guid
        
        validates_with_method :username, :unique_username?

        validates_present :first_name, :last_name, :display_name, :username, :email, :public_key, :cert_guid

        validates_format :username, :with => /^[a-z0-9\-_]+$/
        validates_format :email, :as => :email_address
        
        auto_validate!

        save_callback :after, :create_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor

        join_properties :requester_id

        def unique_username?
          begin
            r = User.by_username(:key => self["username"], :include_docs => false)
            how_many = r["rows"].length
            # If we don't have an object with this name, then we are the first, and it's cool.
            # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
            return true if (how_many == 0) || (how_many == 1 && self.has_key?('_id'))
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to determine if username '#{self['username']}' is unique"
          end
          [ false, "The name #{self["username"]} is not unique!" ]      
        end
        
        def self.find(username)
          User.by_username(:key => username).first or raise ArgumentError
        end
        
        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]
            result[pname] = self.send(pname) unless pname == :cert_guid
            result
          end
        end
        
      end
      
    end
  end
end

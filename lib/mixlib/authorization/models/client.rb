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
      class Client < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        
        view_by :name

        property :name
        property :public_key
        
        validates_with_method :name

        validates_present :name, :public_key

        validates_format :name, :with => /^([a-zA-Z0-9\-_\.])*$/
        #    /^(([:alpha]{1}([:alnum]-){1,62})\.)+([:alpha]{1}([:alnum]-){1,62})$/
        
        auto_validate!

        save_callback :after, :create_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor

        join_properties :name, :requester_id

        def unique_clientname?
          begin
            r = Client.by_name(:key => self["name"], :include_docs => false)
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
          Client.by_name(:key => name).first or raise ArgumentError
        end
        
        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]
            result[pname] = self.send(pname) unless pname == :public_key
            result
          end
        end
        
      end

    end
  end
end

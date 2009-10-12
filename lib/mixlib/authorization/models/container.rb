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
      class Container < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper

        view_by :containername
        view_by :containerpath
        
        property :containername
        property :containerpath  
        
        property :requester_id

        validates_present :containername, :containerpath

        validates_format :containername, :with => /^[a-z0-9\-_]+$/
        validates_format :containerpath, :with => /^[a-z0-9\-_\/]+$/
        
        auto_validate!

        save_callback :after, :create_join
        destroy_callback :before, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Container

        join_properties :containername, :containerpath, :requester_id

        def self.find(name)
          Container.by_containername(:key => name).first or raise ArgumentError
        end

        def for_json
          self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            # BUGBUG - I hate stripping a property this way.  We should really do this differently [cb]
            result[pname] = self.send(pname) unless pname == :requester_id
            result
          end
        end
      end  

    end
  end
end

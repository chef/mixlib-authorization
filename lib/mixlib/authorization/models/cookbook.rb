#
# Author:: Christopher Brown <cb@opscode.com>
# Author:: Tim Hinderliter <tim@opscode.com>
#
# Copyright 2009, 2010, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

# TODO: make sure this comment is correct.
# Models a Cookbook -- this is the container that holds other cookbook version
# and its ACL's are checked on CookbookVersion create.
module Mixlib
  module Authorization
    module Models
      class Cookbook < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        
        view_by :display_name

        property :display_name
        property :orgname
        
        validates_present :display_name, :orgname
        
        auto_validate!

        inherit_acl
        
        create_callback :after, :save_inherited_acl, :create_join
        update_callback :after, :update_join
        destroy_callback :before, :delete_join
        
        join_type Mixlib::Authorization::Models::JoinTypes::Object 
        join_properties :requester_id
        
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

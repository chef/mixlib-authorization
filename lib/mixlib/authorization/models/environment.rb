#
# Author:: Nuo Yan <nuo@opscode.com>
#
# Copyright 2010, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization
    module Models
      class Environment < CouchRest::ExtendedDocument
        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper

        view_by :name

        property :name
        property :orgname

        validates_present :name, :orgname

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

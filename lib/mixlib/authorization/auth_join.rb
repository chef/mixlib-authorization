#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization
    class AuthJoin < CouchRest::ExtendedDocument
      include CouchRest::Validation
      include Mixlib::Authorization::AuthHelper
      
      unique_id :gen_guid
      
      view_by :user_object_id
      view_by :auth_object_id
      
      property :user_object_id
      property :auth_object_id

      validates_present :user_object_id, :auth_object_id
      
      auto_validate!

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


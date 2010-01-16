#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#


module Mixlib
  module Authorization
    module JoinHelper
      def self.included(klass)
        klass.extend ClassMethods
      end
      
      def create_join
        Mixlib::Authorization::Log.debug "IN CREATE JOIN"
        join_results = AuthJoin.by_user_object_id(:key=>self.id)
        join_type = self.class.instance_variable_get("@join_type")                

        if join_results.length == 0
          Mixlib::Authorization::Log.debug "IN CREATE JOIN, saving #{join_type} #{self.inspect}"
          auth_join_object = join_type.new(Mixlib::Authorization::Config.authorization_service_uri,self.join_data)
          auth_join_object.save
          Mixlib::Authorization::Log.debug "IN CREATE JOIN, auth_join_object for #{join_type} saved"
          @join_doc = AuthJoin.new({ :user_object_id=>self.id,
                                     :auth_object_id=>auth_join_object.identity["id"]})
          @join_doc.save
          Mixlib::Authorization::Log.debug "IN CREATE JOIN, join doc saved"
          @join_doc
        else
          Mixlib::Authorization::Log.debug "IN CREATE JOIN, updating #{join_type} #{self.inspect}"
          join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
          auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))          
          auth_join_object.update
          Mixlib::Authorization::Log.debug "IN CREATE JOIN, fetched #{auth_join_object.inspect}"                    
        end
      end

      def fetch_join
        Mixlib::Authorization::Log.debug "IN FETCH JOIN: #{join_data.inspect}"      
        join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
        auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))
        Mixlib::Authorization::Log.debug "IN FETCH JOIN: #{auth_join_object.inspect}"
        auth_join_object.fetch
      end
      
      def fetch_join_acl
        Mixlib::Authorization::Log.debug "IN FETCH JOIN ACL: #{join_data.inspect}"      
        join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
        auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))
        Mixlib::Authorization::Log.debug "IN FETCH JOIN ACL: #{auth_join_object.inspect}"      
        auth_join_object.fetch_acl
      end
      
      def delete_join
        Mixlib::Authorization::Log.debug "IN DELETE JOIN ACL: #{join_data.inspect}"
        join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
        auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))
        Mixlib::Authorization::Log.debug "IN DELETE JOIN ACL: #{auth_join_object.inspect}"
        join_object.destroy
      end

      def update_join_ace(ace_type, ace_data)
        Mixlib::Authorization::Log.debug "IN UPDATE JOIN ACL: #{join_data.inspect}"      
        join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
        auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))
        Mixlib::Authorization::Log.debug "IN UPDATE JOIN ACL: #{auth_join_object.inspect}"      
        auth_join_object.update_ace(ace_type, ace_data)
      end

      def is_authorized?(actor,ace)
        Mixlib::Authorization::Log.debug "IN IS_AUTHORIZED?: #{join_data.inspect}"      
        join_object = AuthJoin.by_user_object_id(:key=>self.id).first or raise ArgumentError
        auth_join_object = self.class.instance_variable_get("@join_type").new(Mixlib::Authorization::Config.authorization_service_uri, { "object_id"=>join_object[:auth_object_id]}.merge(join_data))
        Mixlib::Authorization::Log.debug "IN IS_AUTHORIZED? AUTH_JOIN OBJECT: #{auth_join_object.inspect}"
        auth_join_object.is_authorized?(actor,ace)
      end

      def join_data
        join_elements = self.class.instance_variable_get("@join_elements") || []
        join_elements.inject({ }) {  |memo, join_element|
          name = join_element.to_s
          value = self[name]
          memo[name]=value
          memo
        }
      end

      module ClassMethods
        def join_properties(*args)
          @join_elements = []
          args.each do |join_element|
            @join_elements << join_element
          end
        end
        
        def join_type(join_type)
          @join_type = join_type
        end
      end
    end
  end
end


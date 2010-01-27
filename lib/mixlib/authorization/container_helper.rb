#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

module Mixlib
  module Authorization
    module ContainerHelper
      
      def save_inherited_acl
        org_database = database_from_orgname(self.orgname)
        self.class.instance_variable_get("@container_helper_acl_merger").call(self,org_database)          
      end
      
      def self.included(klass)
        klass.extend ClassMethods
      end
      
      module ClassMethods
        def inherit_acl(parent_name=nil)
          parent_name ||= self.to_s.downcase.split("::").last.pluralize
          Mixlib::Authorization::Log.debug "calling inherit_acl: parent_name: #{parent_name}"
          @container_helper_acl_merger = Proc.new { |sender, org_database|
            container = Mixlib::Authorization::Models::Container.on(org_database).by_containername(:key => parent_name).first
            Mixlib::Authorization::Log.debug "CALLING ACL MERGER: sender: #{sender.inspect}, parent_name: #{parent_name}, org_database: #{org_database}, container: #{container.inspect}"
            raise Mixlib::Authorization::AuthorizationError, "failed to find parent #{parent_name} for ACL inheritance" if container.nil?
            cacl = container.fetch_join_acl
            sacl = sender.fetch_join_acl
            Mixlib::Authorization::Log.debug "container acl: #{cacl.inspect}, sender acl: #{sacl.inspect}"
            sacl.merge!(cacl)
            Mixlib::Authorization::Log.debug "new sender acl: #{sacl.inspect}"            
            sacl.each {  |ace_name,ace_data| sender.update_join_ace(ace_name, ace_data) }
          }
        end
      end
      
    end
  end
end


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
      module ContainerHelper
        
        def save_inherited_acl
          self.class.instance_variable_get("@container_helper_acl_merger").call
        end
        
        def self.included(klass)
          klass.extend ClassMethods
        end
        
        module ClassMethods
          def inherit_acl(parent_name)
            parent_name ||= self.class.to_s.downcase.split("::").last
            org_database = database_from_orgname(self.orgname)

            @container_helper_acl_merger = Proc.new { 
              container = Mixlib::Authorization::Models::Container.on(org_database).by_containername(:key => parent_name).first or raise ArgumentError
              acl = self.fetch_join_acl.merge!(container.fetch_join_acl)
              acl.aces.each {  |ace_name,ace_data| self.update_join_ace(ace_name, ace_data) }
            }
          end
        end
        
      end
    end
  end
end

#
# Author:: Christopher Brown <cb@opscode.com>
# Author:: Nuo Yan <nuo@opscode.com>
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
          parent_name ||= "#{self.to_s.downcase.split("::").last}s"
          Mixlib::Authorization::Log.debug "calling inherit_acl: parent_name: #{parent_name}"
          @container_helper_acl_merger = Proc.new { |sender, org_database|
            begin
              container = Mixlib::Authorization::Models::Container.on(org_database).by_containername(:key => parent_name).first
              Mixlib::Authorization::Log.debug { "CALLING ACL MERGER: sender: #{sender.inspect}, parent_name: #{parent_name}, org_database: #{org_database}, container: #{container.inspect}" }
              if container.nil?
                Mixlib::Authorization::Log.error "CALLING ACL MERGER: sender: #{sender.inspect}, parent_name: #{parent_name}, org_database: #{org_database}, container: #{container.inspect}"
                try_again = Mixlib::Authorization::Models::Container.on(org_database).by_containername(:key => parent_name).first
                Mixlib::Authorization::Log.error "Did a retry work? #{try_again.inspect}"
                raise Mixlib::Authorization::AuthorizationError, "failed to find parent #{parent_name} for ACL inheritance"
              end
              container_join_acl = container.fetch_join_acl
              cacl = Acl.new(container_join_acl)
              sacl = Acl.new(sender.fetch_join_acl)
              Mixlib::Authorization::Log.debug { "CONTAINER ACL: #{cacl.to_user(org_database).inspect},\nSENDER ACL: #{sacl.to_user(org_database).inspect}" }
              sacl.merge!(cacl)
              Mixlib::Authorization::Log.debug { "MERGED SENDER ACL: #{sacl.to_user(org_database).inspect}" }
              sacl.aces.each {  |ace_name,ace| sender.update_join_ace(ace_name, ace.ace) }
            rescue => e
              # 4/11/2011 nuo:
              # This rescue block is generically rescuing all the exceptions occur in the block.
              # But it's actually the right behavior.
              # We want to throw :halt so .save returns false in the case of any error condition, no matter what.
              # That prevents (or at least decrease) the opportunity that the actual object and auth document go out of sync.
              Mixlib::Authorization::Log.error("Inheriting acl from parent container failed. \nERROR: #{e.message}\n#{e.backtrace.join("\n")}")
              throw :halt
            end

            # In the case that no exception occurred, this doubld checks the acl is inherited correctly.
            # If it returns false, .save would return false as well.
            check_inherit_acl_correctness(sender, container_join_acl)
          }
        end

        private
        # Retrieves join acl from sender and compares with container's join acl
        # Returns:  true the join acl from sender contains container's join acl
        #           false otherwise.
        def check_inherit_acl_correctness(sender, container_join_acl)
          begin
            object_join_acl = sender.fetch_join_acl
          rescue => e
            Mixlib::Authorization::Log.error("Failed trying to verify the result of inherit_acl.\nERROR:#{e.message}\n#{e.backtrace.join("\n")}")
            return false
          end
          container_join_acl.merge(object_join_acl) == object_join_acl
        end

      end

    end
  end
end

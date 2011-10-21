#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'chef'
require 'chef/index_queue'
require 'chef/api_client'

module Mixlib
  module Authorization
    module Models
      class Client < CouchRest::ExtendedDocument

        def self.raise_on_failure=(error_class)
          @error_class_for_failure = error_class
        end

        def self.raise_on_invalid=(error_class)
          @error_class_for_invalid = error_class
        end

        def self.failed_to_save!(message)
          error_class = @error_class_for_failure || StandardError
          raise error_class, message
        end

        def self.invalid_object!(message)
          error_class = @error_class_for_invalid || StandardError
          raise error_class, message
        end

        def self.inherit_acl_from_container(parent_container_name)
          parent_container_name = parent_container_name.to_s
          define_method(:parent_container_name) do
            parent_container_name
          end
        end

        inherit_acl_from_container(:clients)

        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        #include Mixlib::Authorization::ContainerHelper
        include Chef::IndexQueue::Indexable

        view_by :clientname

        property :clientname
        alias :name :clientname

        property :orgname
        property :public_key
        property :certificate
        property :validator

        validates_with_method :clientname

        validates_present :clientname, :orgname

        validates_format :clientname, :with => /\A([a-zA-Z0-9\-_\.])*\z/
        #    /^(([:alpha]{1}([:alnum]-){1,62})\.)+([:alpha]{1}([:alnum]-){1,62})$/

        auto_validate!

        #create_callback :after, :add_index, :save_inherited_acl, :create_join
        #update_callback :after, :add_index, :update_join
        destroy_callback :before, :delete_index, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor
        join_properties :clientname, :requester_id


        private :save
        private :save!

        # Save this document, and create the corresponding AuthZ data on behalf
        # of +requesting_actor_id+ which is an AuthZ side id.
        def save_as(requesting_actor_id)
          delete("requestor_id") # clear out old crap.
          was_a_new_doc = new_document?
          result = save
          if result && was_a_new_doc
            create_authz_object_as(requesting_actor_id)
            result = result && save_inherited_acl_as(requesting_actor_id)
            fix_group_membership_as(requesting_actor_id) if result
          else
            update_authz_object_as(requesting_actor_id)
          end
          add_index
          result
        end

        # Same as #save_as, except it will raise an error if the object is
        # invalid or the save fails for some other reason. The specific errors
        # raised are configured by the class methods raise_on_failure= and
        # raise_on_invalid= so you can make it raise merb-friendly BadRequest
        # and InternalServerError exceptions.
        def save_as!(requesting_user)
          unless valid?
            self.class.invalid_object!(errors.full_messages)
          end
          save_as(requesting_user) or self.class.failed_to_save!("Could not save #{self.class} document (id: #{id})")
        end

        def public_key
          Mixlib::Authorization::Log.debug "calling client model public key"
          self[:public_key] || OpenSSL::X509::Certificate.new(self.certificate).public_key
        end

        def add_index
          Mixlib::Authorization::Log.debug "indexing client #{clientname}"
          add_to_index(:database=>self.database.name, :id=>self["_id"], :type=>self.class.to_s.split("::").last.downcase)
          true
        end

        def delete_index
          Mixlib::Authorization::Log.debug "deindexing client #{clientname}"
          delete_from_index(:database=>self.database.name, :orgname=>self["orgname"], :id=>self["_id"], :type=>self.class.to_s.split("::").last.downcase)
          true
        end

        def unique_clientname?
          begin
            r = Client.by_clientname(:key => self["clientname"], :include_docs => false)
            how_many = r["rows"].length
            # If we don't have an object with this name, then we are the first, and it's cool.
            # If we do have *one*, and we have an id, we assume we are safe to save ourself again.
            return true if (how_many == 0) || (how_many == 1 && self.has_key?('_id'))
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to determine if username '#{self['clientname']}' is unique"
          end
          [ false, "The name #{self["clientname"]} is not unique!" ]
        end

        def validator?
          has_validator_name? || validator
        end

        def validator
          # defaults are borken in this sad library
          self["validator"] || false
        end

        def for_json
          result = self.properties.inject({ }) do |result, prop|
            pname = prop.name.to_sym
            #BUGBUG - I hate stripping properties like this.  We should do it differently [cb]
            result[pname] = self.send(pname) unless pname == :public_key
            result
          end
          result[:name] = result[:clientname]
          result
        end

        private

        def save_inherited_acl_as(requesting_actor_id)
          org_database = database_from_orgname(self.orgname)

          container = Mixlib::Authorization::Models::Container.on(org_database).by_containername(:key => parent_container_name).first
          Mixlib::Authorization::Log.debug "CALLING ACL MERGER: object: #{inspect}, parent_name: #{parent_container_name}, org_database: #{org_database}, container: #{container.inspect}"
          raise Mixlib::Authorization::AuthorizationError, "failed to find parent #{parent_container_name} for ACL inheritance" if container.nil?
          authz_object = authz_object_as(requesting_actor_id)
          container_acl_data = container.fetch_join_acl
          container_acl = Acl.new(container_acl_data)
          self_acl = Acl.new(authz_object.fetch_acl)
          # debug logging shouldn't be making api calls
          #Mixlib::Authorization::Log.debug "CONTAINER ACL: #{container_acl.to_user(org_database).inspect},\nCLIENT ACL: #{self_acl.to_user(org_database).inspect}"
          self_acl.merge!(container_acl)
          # debug logging shouldn't be making api calls
          #Mixlib::Authorization::Log.debug "MERGED CLIENT ACL: #{self_acl.to_user(org_database).inspect}"
          # TODO: Y U NO HAVE BULK ACE UPDATE
          self_acl.aces.each {  |ace_name,ace| authz_object.update_ace(ace_name, ace.ace) }

          # In the case that no exception occurred, this doubld checks the acl is inherited correctly.
          # If it returns false, .save would return false as well.
          #check_inherit_acl_correctness(sender, container_join_acl)

          begin
            object_acl = authz_object.fetch_acl
          rescue => e
            Mixlib::Authorization::Log.error("Failed trying to verify the result of inherit_acl.\nERROR:#{e.message}\n#{e.backtrace.join("\n")}")
            return false
          end
          container_acl_data.merge(object_acl) == object_acl
        end

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

        def has_validator_name?
          clientname == orgname + "-validator"
        end

        # Adds this client to the clients group, and adds the admins group to
        # this client's ACLs.
        #--
        # Note: the requesting_actor_id is not currently used because groups
        # have not been updated to use explicit requesting_actor_ids. Consider
        # this a TODO.
        def fix_group_membership_as(requesting_actor_id)
          Merb.logger.debug "about to spin..."
          # Adds the client to the clients group, retrying in case authz is backed up by our joke of a database.
          spin_on_error do
            # BUGBUG adding the client to the organization's "clients" group should probably be done by policy outside the service somewhere [cb]
            Merb.logger.debug { "Adding client #{clientname} to clients group" }
            clients_group = Mixlib::Authorization::Models::Group.on(database).by_groupname(:key=>"clients").first
            clients_group.add_actor(self)
          end

        rescue Exception => e
          Merb.logger.error "Unexpected failure type in adding groups during client creation: #{e.inspect}, #{e.backtrace.join(",\n")}"
          destroy
          self.class.failed_to_save!("Failed to update groups in client creation")
        end


        def spin_on_error(retries=5)
          ret = false

          catch(:done) do
            0.upto(retries) do |n|
              Merb.logger.debug "spinning... trying #{retries}"
              if yield
                ret = true
                throw :done
              else
                Merb.logger.error "SPINNING ON ERROR: #{retries}"
                sleep(rand(4))
              end
            end
          end
          ret
        end

      end
    end
  end
end

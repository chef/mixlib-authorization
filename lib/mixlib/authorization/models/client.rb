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
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        include Chef::IndexQueue::Indexable        
        
        view_by :clientname

        property :clientname
        property :orgname
        property :public_key        
        property :certificate
        property :validator
        
        validates_with_method :clientname

        validates_present :clientname, :orgname

        validates_format :clientname, :with => /^([a-zA-Z0-9\-_\.])*$/
        #    /^(([:alpha]{1}([:alnum]-){1,62})\.)+([:alpha]{1}([:alnum]-){1,62})$/
        
        auto_validate!
        
        inherit_acl

        create_callback :after, :add_index, :save_inherited_acl, :create_join
        update_callback :after, :add_index, :update_join
        destroy_callback :before, :delete_index, :delete_join

        join_type Mixlib::Authorization::Models::JoinTypes::Actor
        join_properties :clientname, :requester_id

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
        
        def has_validator_name?
          clientname == orgname + "-validator"
        end
      end

    end
  end
end

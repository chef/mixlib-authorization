#
# Author:: Christopher Brown <cb@opscode.com>
#
# Copyright 2009, Opscode, Inc.
#
# All rights reserved - do not redistribute
#

require 'mixlib/authentication/signedheaderauth'
require 'openssl'

module Mixlib
  module Authorization
    module Models
      class JoinDocument
        attr_reader :identity
        attr_reader :resource
        attr_reader :base_url
        attr_reader :join_data
        
        include Mixlib::Authorization::AuthHelper
        
        def initialize(base_url,left_join_data)
          @join_data = left_join_data
          @resource = self.class.name.split("::").last.downcase.pluralize
          @base_url = base_url
        end
        
        def save
          url = [base_url,resource].join("/")
          requester_id = join_data["requester_id"]
          Mixlib::Authorization::Log.debug "IN SAVE: join_data #{join_data.inspect}"
          headers = {:accept => "application/json", :content_type => "application/json"}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          headers["X-Ops-User-Id"] = 'front-end-service'

          Mixlib::Authorization::Log.debug "IN SAVE: url: #{url.inspect}, with payload: #{join_data.to_json}"
          rest = RestClient::Resource.new(url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
          @identity = JSON.parse(rest.post(join_data.to_json))
          Mixlib::Authorization::Log.debug "IN SAVE: response: #{@identity.inspect}"
          @identity
        end
        
        def fetch
          Mixlib::Authorization::Log.debug "IN FETCH: #{self.inspect}"
          object_id = join_data["object_id"]
          url = [base_url,resource,object_id].join("/")
          requester_id = join_data["requester_id"]        
          Mixlib::Authorization::Log.debug "IN FETCH: #{url.inspect}"
          
          headers = {:accept => "application/json", :content_type => "application/json"}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          headers["X-Ops-User-Id"] = 'front-end-service'
          rest = RestClient::Resource.new(url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
          @identity  = JSON.parse(rest.get).merge({ "id"=>object_id })
          Mixlib::Authorization::Log.debug "IN FETCH: response #{@identity.inspect}" 
          @identity
        end

        def update
          Mixlib::Authorization::Log.debug "IN UPDATE: #{self.inspect}"        
        end
        
        def fetch_acl
          Mixlib::Authorization::Log.debug "IN FETCH ACL: #{self.inspect}"
          object_id = join_data["object_id"]        
          url = [base_url,resource,object_id,"acl"].join("/")
          requester_id = join_data["requester_id"]
          Mixlib::Authorization::Log.debug "IN FETCH ACL: #{url}"        
          
          headers = {:accept => "application/json", :content_type => "application/json"}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          headers["X-Ops-User-Id"] = 'front-end-service'
          rest = RestClient::Resource.new(url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
          @identity  = JSON.parse(rest.get)

          Mixlib::Authorization::Log.debug "FETCH ACL: #{@identity.inspect}"
          @identity
        end

        def is_authorized?(actor, ace)
          object_id = join_data["object_id"]        
          url = [base_url,resource,object_id,"acl",ace,"actors", actor].join("/")
          url_dbg = [base_url,resource,object_id,"acl",ace,].join("/")
          requester_id = join_data["requester_id"]
          Mixlib::Authorization::Log.debug "IN IS_AUTHORIZED: #{self.inspect} \n\twith actor: #{actor}\n\tace: #{ace}\n\turl:#{url}"

          headers = {:accept=>"application/json", :content_type=>"application/json"}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          headers["X-Ops-User-Id"] = 'front-end-service'
          
          begin
            rest = RestClient::Resource.new(url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
            JSON.parse(rest.get)
          rescue RestClient::ResourceNotFound
            false
          end

        end
        
        #e.g. ace_name: 'delete', ace_data: {"actors"=>["signing_caller"], "groups"=>[]}
        def update_ace(ace_name, ace_data)
          Mixlib::Authorization::Log.debug "IN UPDATE ACE: #{self.inspect}, ace_data: #{ace_data.inspect}"
          
          # update actors and groups
          begin
            object_id = join_data["object_id"]
            
            headers = {:accept=>:json, :content_type=>:json, "X-Ops-Requesting-Actor-Id" => join_data["requester_id"], "X-Ops-User-Id"=>'front-end-service'}
            
            url_get_ace = [base_url,resource, object_id,"acl",ace_name].join("/")
            rest = RestClient::Resource.new(url_get_ace,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
            current_ace = JSON.parse(rest.get)
            new_ace = Hash.new
            ["actors", "groups"].each do |actor_type|
              if ace_data.has_key?(actor_type)
                to_delete = current_ace[actor_type] - ace_data[actor_type]
                to_put    = ace_data[actor_type] - current_ace[actor_type]
                new_ace[actor_type] = current_ace[actor_type] - to_delete + to_put
              end                
            end
            Mixlib::Authorization::Log.debug("IN UPDATE ACE: Current ace: #{current_ace.inspect}, Future ace: #{new_ace.inspect}")
            target_url = [base_url,resource, object_id,"acl",ace_name].join("/")
            rest = RestClient::Resource.new(target_url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
            resp = JSON.parse(rest.put(new_ace.to_json))
            Mixlib::Authorization::Log.debug("IN UPDATE ACE: response #{resp.inspect}")
            resp
          rescue StandardError => se
            Mixlib::Authorization::Log.error "Failed to update ace: #{se.message} " + se.backtrace.join(",\n")
            raise
          end
        end
        
        def delete
          object_id = join_data["object_id"]        
          url = [base_url,resource,object_id].join("/")
          
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          headers["X-Ops-User-Id"] = 'front-end-service'
          rest = RestClient::Resource.new(target_url,:headers=>headers, :timeout=>1800, :open_timeout=>1800)
          resp = JSON.parse(rest.delete)
          
          @identity = resp
          true        
        end
        
      end
    end    
  end
end

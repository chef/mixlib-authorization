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
        
        def initialize(base_url,left_join_data)
          @join_data = left_join_data
          @resource = self.class.name.split("::").last.downcase.pluralize
          @base_url = base_url
        end
        
        def save
          url = [base_url,resource].join("/")
          requester_id = join_data["requester_id"]
          Mixlib::Authorization::Log.debug "IN SAVE: join_data #{join_data.inspect}"
          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          
          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers,
            :payload=>join_data.to_json
          }
          Mixlib::Authorization::Log.debug "IN SAVE: url: #{url.inspect}, with payload: #{options[:payload]}"
          resp = rest.request(:post,url,options)
          Mixlib::Authorization::Log.debug "IN SAVE: response: #{resp.inspect}"
          @identity = resp
        end
        
        def fetch
          Mixlib::Authorization::Log.debug "IN FETCH: #{self.inspect}"
          object_id = join_data["object_id"]
          url = [base_url,resource,object_id].join("/")
          requester_id = join_data["requester_id"]        
          Mixlib::Authorization::Log.debug "IN FETCH: #{url.inspect}"
          
          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          
          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers
          }

          resp = rest.request(:get,url,options)
          Mixlib::Authorization::Log.debug "IN FETCH: response #{resp.inspect}"        
          @identity = resp.merge({ "id"=>object_id })
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
          
          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          
          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers
          }

          resp = rest.request(:get,url,options)
          @identity = resp
        end

        def is_authorized?(actor, ace)
          Mixlib::Authorization::Log.debug "IN IS_AUTHORIZED: #{self.inspect}, with actor: #{actor} and ace: #{ace}"
          object_id = join_data["object_id"]        
          url = [base_url,resource,object_id,"acl",ace,"actors", actor].join("/")
          requester_id = join_data["requester_id"]
          Mixlib::Authorization::Log.debug "IN IS_AUTHORIZED: #{url}"        
          
          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          
          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers
          }
          
          begin
            resp = rest.request(:get,url,options)
          rescue RestClient::ResourceNotFound
            false
          end
        end
        
        #e.g. ace_name: 'delete', ace_data: {"actors"=>["signing_caller"], "groups"=>[]}
        def update_acl(ace_name, ace_data)
          Mixlib::Authorization::Log.debug "IN UPDATE ACL: #{self.inspect}, ace_data: #{ace_data.inspect}"
          
          # update actors and groups
          begin
            object_id = join_data["object_id"]
            
            headers = {:accept=>"application/json", :content_type=>'application/json', "X-Ops-Requesting-Actor-Id" => join_data["requester_id"]}
            options = { :authenticate=> true,
              :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
              :user_id=>'front-end service',
              :headers=>headers,
            }
            
            rest = Opscode::REST.new
            url_get_ace = [base_url,resource, object_id,"acl",ace_name].join("/")
            current_ace = rest.request(:get, url_get_ace, options)
            new_ace = Hash.new
            ["actors", "groups"].each do |actor_type|
              if ace_data.has_key?(actor_type)
                to_delete = current_ace[actor_type] - ace_data[actor_type]
                to_put    = ace_data[actor_type] - current_ace[actor_type]
                new_ace[actor_type] = current_ace[actor_type] - to_delete + to_put
              end                
            end
            Mixlib::Authorization::Log.debug("IN UPDATE ACL: Current ace: #{current_ace.inspect}, Future ace: #{new_ace.inspect}")
            target_url = [base_url,resource, object_id,"acl",ace_name].join("/")
            options[:payload] = new_ace.to_json
            resp = rest.request(:put,target_url,options)     
          rescue StandardError => se
            Mixlib::Authorization::Log.debug "Failed to update acl: #{se.message} " + se.backtrace.join(",\n")
            raise
          end
        end
        
        def delete
          object_id = join_data["object_id"]        
          url = [base_url,resource,object_id].join("/")
          
          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
          
          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers
          }

          resp = rest.request(:delete,url,options)
          
          @identity = resp
          true        
        end
        
      end
    end    
  end
end

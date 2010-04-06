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
      module JoinTypes
        class Group < Mixlib::Authorization::Models::JoinDocument
          def save
            Mixlib::Authorization::Log.debug "SAVING GROUP #{self.inspect}"
            super
            add_actors
            add_groups        
          end

          def update
            Mixlib::Authorization::Log.debug "UPDATING GROUP #{self.inspect}"
            fetch
            remove_current_actors
            remove_current_groups
            add_actors
            add_groups
          end
          
          def remove_current_actors
            identity["actors"].each do |actor_id|
              next if join_data && join_data["actors"] && join_data["actors"].include?(actor_id)
              
              Mixlib::Authorization::Log.debug("Removing actor: #{actor_id}")
              url = [base_url,resource,identity["id"],"actors",actor_id].join("/")
              requester_id = join_data["requester_id"]
              rest = Opscode::REST.new
              headers = {:accept=>"application/json", :content_type=>'application/json'}
              headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
              
              options = { :authenticate=> true,
                :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
                :user_id=>'front-end service',
                :headers=>headers,
              }
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} remove_current_actors, DELETE #{url}")
              resp = rest.request(:delete,url,options)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end

          def remove_current_groups
            identity["groups"].each do |group_id|
              next if join_data && join_data["groups"] && join_data["groups"].include?(group_id)

              Mixlib::Authorization::Log.debug("Removing group: #{group_id}")
              url = [base_url,resource,identity["id"],"groups",group_id].join("/")
              requester_id = join_data["requester_id"]
              rest = Opscode::REST.new
              headers = {:accept=>"application/json", :content_type=>'application/json'}
              headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
              
              options = { :authenticate=> true,
                :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
                :user_id=>'front-end service',
                :headers=>headers,
              }
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} remove_current_groups, DELETE #{url}")
              resp = rest.request(:delete,url,options)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end
          
          def add_actors
            join_data["actors"].each do |actor_id|
              next if identity && identity["actors"] && identity["actors"].include?(actor_id)
              
              Mixlib::Authorization::Log.debug("Adding actor: #{actor_id}")
              url = [base_url,resource,identity["id"],"actors",actor_id].join("/")
              requester_id = join_data["requester_id"]
              rest = Opscode::REST.new
              headers = {:accept=>"application/json", :content_type=>'application/json'}
              headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
              
              options = { :authenticate=> true,
                :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
                :user_id=>'front-end service',
                :headers=>headers,
              }
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_actors, PUT #{url}")
              resp = rest.request(:put,url,options)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end

          def add_groups
            join_data["groups"].each do |group_id|
              next if identity && identity["groups"] && identity["groups"].include?(group_id)
              
              Mixlib::Authorization::Log.debug("Adding group: #{group_id}")
              url = [base_url,resource,identity["id"],"groups",group_id].join("/")
              requester_id = join_data["requester_id"]
              rest = Opscode::REST.new
              headers = {:accept=>"application/json", :content_type=>'application/json'}
              headers["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
              
              options = { :authenticate=> true,
                :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
                :user_id=>'front-end service',
                :headers=>headers,
              }
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_groups, PUT #{url}")
              resp = rest.request(:put,url,options)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end
        end

        class Actor < Mixlib::Authorization::Models::JoinDocument
        end

        class Container < Mixlib::Authorization::Models::JoinDocument
        end

        class Object < Mixlib::Authorization::Models::JoinDocument
        end    
      end
    end

  end
end

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
          def resource
            "groups"
          end

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

          def request_helper(http_method, request_path, options={})
            options[:headers] ||= {}
            requester_id = join_data["requester_id"]
            options[:headers]["X-Ops-Requesting-Actor-Id"] = requester_id if requester_id
            options[:headers].merge!({:accept=>'application/json', :content_type=>'application/json', "X-Ops-Userid"=>'front-end-service'})
            options[:payload] ||= ""
            JSON.parse(RestClient::Request.new(
                                               :method => http_method.to_sym,
                                               :url    => request_path,
                                               :headers => options[:headers],
                                               :timeout => 1800,
                                               :open_timeout => 1800,
                                               :raw_response => false,
                                               :payload => options[:payload].to_json
                                               ).execute)
          end

          private :request_helper

          def remove_current_actors
            identity["actors"].each do |actor_id|
              next if join_data && join_data["actors"] && join_data["actors"].include?(actor_id)
              
              Mixlib::Authorization::Log.debug("Removing actor: #{actor_id}")
              url = [base_url,resource,identity["id"],"actors",actor_id].join("/")
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} remove_current_actors, DELETE #{url}")
              resp = request_helper(:delete,url)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end

          def remove_current_groups
            identity["groups"].each do |group_id|
              next if join_data && join_data["groups"] && join_data["groups"].include?(group_id)

              Mixlib::Authorization::Log.debug("Removing group: #{group_id}")
              url = [base_url,resource,identity["id"],"groups",group_id].join("/")
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} remove_current_groups, DELETE #{url}")
              resp = request_helper(:delete,url)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end
          
          def add_actors
            join_data["actors"].each do |actor_id|
              next if identity && identity["actors"] && identity["actors"].include?(actor_id)
              
              Mixlib::Authorization::Log.debug("Adding actor: #{actor_id}")
              url = [base_url,resource,identity["id"],"actors",actor_id].join("/")
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_actors, PUT #{url}")
              resp = request_helper(:put,url)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end

          def add_groups
            join_data["groups"].each do |group_id|
              next if identity && identity["groups"] && identity["groups"].include?(group_id)
              Mixlib::Authorization::Log.debug("Adding group: #{group_id}")
              url = [base_url,resource,identity["id"],"groups",group_id].join("/")
              Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_groups, PUT #{url}")
              resp = request_helper(:put,url)
              Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
            end
          end
        end
        
        class Actor < Mixlib::Authorization::Models::JoinDocument
          def resource
            "actors"
          end

        end
        
        class Container < Mixlib::Authorization::Models::JoinDocument
        end

        class Object < Mixlib::Authorization::Models::JoinDocument
        end    
      end
    end

  end
end

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
      class Group < CouchRest::ExtendedDocument
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        
        view_by :groupname

        property :groupname

        validates_present :groupname

        validates_format :groupname, :with => /^[a-z0-9\-_]+$/
        
        auto_validate!

        create_callback :before, :trim_actors_and_groups
        update_callback :before, :trim_actors_and_groups
        create_callback :after, :create_join, :transform_ids
        update_callback :after, :update_join, :transform_ids
        destroy_callback :before, :delete_join

        def trim_actors_and_groups
          self["actor_and_group_names"].each { |key,value| self["actor_and_group_names"][key]=value.uniq.sort }
        end

        def transform_ids
          self["actors"], self["groups"] = transform_names_to_auth_ids(database,self["actor_and_group_names"])
        end

        def add_actor(actorname, database)
          base_url = Mixlib::Authorization::Config.authorization_service_uri
          actor_id = transform_actor_ids([actorname], database, :to_auth).first
          group_auth_id =  AuthJoin.by_user_object_id(:key=>self["_id"]).first.auth_object_id
          url = [base_url,"groups",group_auth_id,"actors",actor_id].join("/")
          Mixlib::Authorization::Log.debug("Adding actor: #{actor_id}, url: #{url.inspect}")

          rest = Opscode::REST.new
          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = self[:requester_id]

          options = { :authenticate=> true,
            :user_secret=>OpenSSL::PKey::RSA.new(Mixlib::Authorization::Config.private_key),
            :user_id=>'front-end service',
            :headers=>headers,
          }
          Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_actors, PUT #{url}")
          resp = rest.request(:put,url,options)
          Mixlib::Authorization::Log.debug("response: #{resp.inspect}")
        end
        
        join_type Mixlib::Authorization::Models::JoinTypes::Group

        join_properties :groupname, :actors, :groups, :requester_id
        
        def for_json
          actors_and_groups_auth = fetch_join
          actors_and_groups = {
            "actors" => transform_actor_ids(actors_and_groups_auth["actors"], database, :to_user),
            "groups" => transform_group_ids(actors_and_groups_auth["groups"], database, :to_user)}
          Mixlib::Authorization::Log.debug("join_data: #{actors_and_groups.inspect}")
          self.properties.inject({ }) { |result, prop|
            pname = prop.name.to_sym
            result[pname] = self.send(pname)
            result
          }.merge(actors_and_groups)
        end
      end  

    end
  end
end

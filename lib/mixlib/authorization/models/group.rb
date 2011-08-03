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
        include Authorizable
        include CouchRest::Validation
        include Mixlib::Authorization::AuthHelper
        include Mixlib::Authorization::JoinHelper
        include Mixlib::Authorization::ContainerHelper
        
        view_by :groupname
        view_by :orgname

        property :groupname
        property :orgname

        validates_present :groupname
        validates_present :orgname

        validates_format :groupname, :with => /^[a-z0-9\-_]+$/
        
        auto_validate!
        
        inherit_acl

        create_callback :before, :trim_actors_and_groups
        update_callback :before, :trim_actors_and_groups
        create_callback :after, :save_inherited_acl, :create_join, :transform_ids
        update_callback :after, :update_join, :transform_ids
        destroy_callback :before, :delete_join

        def trim_actors_and_groups
          self["actor_and_group_names"].each { |key,value| self["actor_and_group_names"][key]=value.uniq.sort }
        end

        def transform_ids
          actors_by_type = self["actor_and_group_names"]

          actornames = actors_by_type["users"] || []
          clientnames = actors_by_type["clients"] || []
          groupnames = actors_by_type["groups"] || []

          # set the organization database for use with global groups
          org_db = (orgname && database_from_orgname(orgname)) || database

          if true #DARKLAUNCH
            user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
            users = user_mapper.find_all_for_authz_map(actornames)
            actor_ids = users.map {|u| u.authz_id}
          else
            actor_ids = actornames.uniq.inject([]) do |memo, actorname|
              user = Mixlib::Authorization::Models::User.by_username(:key => actorname).first
              user && (auth_join = AuthJoin.by_user_object_id(:key=>user.id).first) && (memo << auth_join.auth_object_id)
              memo
            end
          end

          client_ids = clientnames.uniq.inject([]) do |memo, clientname|
            client = Mixlib::Authorization::Models::Client.on(org_db).by_clientname(:key=>clientname).first
            client && (auth_join = AuthJoin.by_user_object_id(:key=>client.id).first) && (memo << auth_join.auth_object_id)
            memo
          end

          actor_ids.concat(client_ids)

          group_ids = groupnames.uniq.inject([]) do |memo, groupname|
            group = Mixlib::Authorization::Models::Group.on(org_db).by_groupname(:key=>groupname).first
            group && (auth_join = AuthJoin.by_user_object_id(:key=>group.id).first) && (memo << auth_join.auth_object_id if auth_join)
            memo
          end
          
          self["actors"], self["groups"] = [actor_ids, group_ids]
        end

        def add_actor(actorname, database)
          Mixlib::Authorization::Log.debug { "Adding actor: #{actorname.inspect} in database #{database}\n#{caller(3)[0..3].map {|l| "\t#{l}"}.join("\n")}"}
          base_url = Mixlib::Authorization::Config.authorization_service_uri
          if actor_id = transform_actor_ids([actorname], database, :to_auth).first
            Mixlib::Authorization::Log.debug { "Found actor id #{actor_id.inspect} for #{actorname}"}
          else
            raise "No actor id fround by #transform_actor_ids for #{actorname} in database #{database}"
          end
          group_auth_id =  AuthJoin.by_user_object_id(:key=>self["_id"]).first.auth_object_id
          url = [base_url,"groups",group_auth_id,"actors",actor_id].join("/")
          Mixlib::Authorization::Log.debug("Adding actor: #{actor_id}, url: #{url.inspect}")

          headers = {:accept=>"application/json", :content_type=>'application/json'}
          headers["X-Ops-Requesting-Actor-Id"] = self[:requester_id]
          headers["X-Ops-Userid"] = 'front-end service'

          Mixlib::Authorization::Log.debug("In #{self.class.to_s} add_actors, PUT #{url}")
          begin
            RestClient::Resource.new(url, :headers=>headers, 
                                     :timeout=>1800, :open_timeout=>1800).put({}.to_json)
          rescue Exception => e
            error_message = "Failed to add actor #{actorname} to group #{self.groupname}, #{e.inspect} #{e.backtrace.join(",")}"
            raise Mixlib::Authorization::AuthorizationError, error_message
          end
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

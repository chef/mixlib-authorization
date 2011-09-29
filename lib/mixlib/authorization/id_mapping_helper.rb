
module Mixlib
  module Authorization
    module IDMappingHelper

      def actor_to_user(actor, org_database)
        raise ArgumentError, "must supply actor" unless actor

        user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
        if user = user_mapper.find_by_authz_id(actor)
          Mixlib::Authorization::Log.debug("actor to user: authz id: #{actor} is a user named #{user.username}")
        else
          begin
            client_join_entry = AuthJoin.by_auth_object_id(:key=>actor).first
            user = Mixlib::Authorization::Models::Client.on(org_database).get(client_join_entry.user_object_id)
            Mixlib::Authorization::Log.debug("actor to user: authz id: #{actor} is a client named #{user.clientname}")
          rescue StandardError=>se
            # BUGBUG: why rescue?
            Mixlib::Authorization::Log.error "Failed to turn actor #{actor} into a user or client: #{se}"
            nil
          end
        end
        user
      end

      def transform_actor_ids(incoming_actors, org_database, direction)
        case direction
        when :to_user
          lookup_usernames_for_authz_ids(incoming_actors, org_database)
        when :to_auth
          lookup_authz_side_ids_for(incoming_actors, org_database)
        end
      end

      def lookup_usernames_for_authz_ids(actors, org_database)
        usernames = []
        # Find all the users in one query like a boss
        user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
        users = user_mapper.find_all_by_authz_id(actors)
        remaining_actors = actors - users.map(&:authz_id)
        usernames.concat(users.map(&:username))
        Mixlib::Authorization::Log.debug { "Found #{users.size} users in actors list: #{actors.inspect} users: #{usernames}" }

        # 2*N requests to couch for the clients :(
        actor_names = remaining_actors.inject(usernames) do |clientnames, actor_id|
          if client = actor_to_user(actor_id, org_database)
            Mixlib::Authorization::Log.debug { "incoming_actor: #{actor_id} is a client named #{client.clientname}" }
            clientnames << client.clientname
          else
            Mixlib::Authorization::Log.debug { "incoming_actor: #{actor_id} is not a recognized user or client!" }
            clientnames
          end
        end
        Mixlib::Authorization::Log.debug { "Mapped actors #{actors.inspect} to users #{actor_names}" }
        actor_names
      end

      def lookup_authz_side_ids_for(actors, org_database)
        authz_ids = []
        #look up all the users with one query like a boss
        user_mapper = Opscode::Mappers::User.new(Opscode::Mappers.default_connection, nil, 0)
        users = user_mapper.find_all_for_authz_map(actors)
        authz_ids.concat(users.map(&:authz_id))
        actors -= users.map(&:username)

        # 2*N requests to couch for the clients :'(
        transformed_ids = actors.inject(authz_ids) do |client_authz_ids, clientname|
          if client = Mixlib::Authorization::Models::Client.on(org_database).by_clientname(:key=>clientname).first
            Mixlib::Authorization::Log.debug { "incoming actor: #{clientname} is a client with authz_id #{client.authz_id.inspect}" }
            client_authz_ids << client.authz_id
          else
            Mixlib::Authorization::Log.debug "incoming_actor: #{clientname} is not a recognized user or client!"
            client_authz_ids
          end
        end
        Mixlib::Authorization::Log.debug { "mapped actors: #{actors.inspect} to auth ids: #{transformed_ids.inspect}"}
        transformed_ids
      end

      def transform_group_ids(incoming_groups, org_database, direction)
        incoming_groups.inject([]) do |outgoing_groups, incoming_group|
          group = case direction
                  when  :to_user
                    auth_group_to_user_group(incoming_group, org_database)
                  when  :to_auth
                    user_group_to_auth_group(incoming_group, org_database)
                  end
          Mixlib::Authorization::Log.debug "incoming_group: #{incoming_group} is not a recognized group!" if group.nil?
          group.nil? ? outgoing_groups : outgoing_groups << group
        end
      end

      def auth_group_to_user_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        Mixlib::Authorization::Log.debug("auth group to user group: #{group_id}, database: #{org_database && org_database.name}")
        auth_join = AuthJoin.by_auth_object_id(:key=>group_id).first
        user_group = begin
                       Mixlib::Authorization::Models::Group.on(org_database).get(auth_join.user_object_id).groupname
                     rescue StandardError=>se
                       Mixlib::Authorization::Log.error "Failed to turn auth group id #{group_id} into a user-side group: #{se}"
                       nil
                     end

        Mixlib::Authorization::Log.debug("user group: #{user_group}")
        user_group
      end

      def user_group_to_auth_group(group_id, org_database)
        raise ArgumentError, "must supply group id" unless group_id
        group_obj = Mixlib::Authorization::Models::Group.on(org_database).by_groupname(:key=>group_id).first
        Mixlib::Authorization::Log.debug("user-side group: #{group_obj.inspect}")
        auth_join = group_obj && AuthJoin.by_user_object_id(:key=>group_obj["_id"]).first
        Mixlib::Authorization::Log.debug("user group to auth group: #{group_id}, database: #{org_database && org_database.name},\n\tuser_group: #{group_obj.inspect}\n\tauth_join: #{auth_join.inspect}")
        raise Mixlib::Authorization::AuthorizationError, "failed to find group or auth object!" if auth_join.nil?
        auth_group = auth_join.auth_object_id
        Mixlib::Authorization::Log.debug("auth group: #{auth_group}")
        auth_group
      end

    end
  end
end

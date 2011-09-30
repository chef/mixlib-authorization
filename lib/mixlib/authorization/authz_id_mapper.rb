

module Mixlib
  module Authorization

    class InvalidGroupMember < ArgumentError
    end

    # == AuthzIDMapper
    # Responsible for mapping user side object names to authz ids. This is used
    # for translating authz side ACLs and Groups to their user-side
    # representations (and the reverse).
    class AuthzIDMapper

      attr_reader :org_db
      attr_reader :user_mapper

      def initialize(org_db, user_mapper, clients_mapper=nil,clients_in_sql=false)
        @group_authz_ids_by_name = {}
        @group_names_by_authz_id = {}

        @actor_authz_ids_by_name = {}
        @actor_names_by_authz_id = {}

        @org_db = org_db
        @user_mapper = user_mapper
      end

      def actor_authz_ids_to_names(actor_ids)
        usernames = []
        Mixlib::Authorization::Log.debug { "Found #{users.size} users in actors list: #{actor_ids.inspect} users: #{usernames}" }

        users = users_by_authz_ids(actor_ids)
        remaining_actors = actor_ids - users.map(&:authz_id)

        usernames = users.map(&:username)
        # 2*N requests to couch for the clients :(
        actor_names = remaining_actors.inject(usernames) do |clientnames, actor_id|
          if clientname = client_authz_id_to_name(actor_id)
            clientnames << clientname
          else
            clientnames
          end
        end
        Mixlib::Authorization::Log.debug { "Mapped actors #{actors.inspect} to users #{actor_names}" }
        actor_names
      end

      def group_authz_ids_to_names(group_ids)
        group_ids.map {|group_id| group_authz_id_to_name(group_id)}.compact
      end

      def client_names_to_authz_ids(client_names)
        client_names.map do |clientname|
          unless client = Models::Client.on(org_db).by_clientname(:key=>clientname).first
            raise InvalidGroupMember, "Client #{clientname} does not exist"
          end
          cache_actor_mapping(client.name, client.authz_id)
          client.authz_id
        end
      end

      def user_names_to_authz_ids(user_names)
        users = user_mapper.find_all_for_authz_map(user_names)
        unless users.size == user_names.size
          missing_user_names = user_names.select {|name| !users.any? {|user| user.name == name}}
          raise InvalidGroupMember, "Users #{missing_user_names.join(', ')} do not exist"
        end
        users.each {|u| cache_actor_mapping(u.name, u.authz_id) }
        users.map {|u| u.authz_id}
      end

      def group_names_to_authz_ids(group_names)
        group_names.map {|g| group_name_to_authz_id(g)}
      end

      private

      def cache_actor_mapping(name, authz_id)
        @actor_names_by_authz_id[authz_id] = name
        @actor_authz_ids_by_name[name] = authz_id
      end

      def cache_group_mapping(name, authz_id)
        @group_names_by_authz_id[authz_id] = name
        @group_authz_ids_by_name[name] = authz_id
      end

      def users_by_authz_ids(authz_ids)
        # Find all the users in one query like a boss
        users = @user_mapper.find_all_by_authz_id(authz_ids)
        users.each {|u| cache_actor_mapping(u.name, u.authz_id)}
        users
      end


      def client_authz_id_to_name(client_authz_id)
        if name = @actor_names_by_authz_id[client_authz_id]
          name
        elsif client_join_entry = AuthJoin.by_auth_object_id(:key=>client_authz_id).first
          client = Mixlib::Authorization::Models::Client.on(org_db).get(client_join_entry.user_object_id)
          cache_actor_mapping(client.name, client_authz_id)
          client.name
        else
          nil
        end
      end

      def group_name_to_authz_id(group_name)
        if authz_id = @group_authz_ids_by_name[group_name]
          authz_id
        elsif group = Models::Group.on(org_db).by_groupname(:key=>group_name).first
          cache_group_mapping(group_name, group.authz_id)
          group.authz_id
        else
          raise InvalidGroupMember, "group #{group_name} does not exist"
        end
      end

      def group_authz_id_to_name(authz_id)
        if name = @group_names_by_authz_id[authz_id]
          name
        elsif auth_join = AuthJoin.by_auth_object_id(:key=>authz_id).first
          name = Mixlib::Authorization::Models::Group.on(org_db).get(auth_join.user_object_id).groupname
          cache_group_mapping(name, authz_id)
          name
        else
          nil
        end
      end
    end

  end
end

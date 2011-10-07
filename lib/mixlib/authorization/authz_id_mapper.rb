

module Mixlib
  module Authorization

    class InvalidGroupMember < ArgumentError
    end

    # == AuthzIDMapper
    # Responsible for mapping user side object names to authz ids. This is used
    # for translating authz side ACLs and Groups to their user-side
    # representations (and the reverse).
    class AuthzIDMapper

      attr_reader :couch_db
      attr_reader :user_mapper

      # Create a new AuthzIDMapper
      #=== Arguments
      # * couch_db::: A CouchRest database. When converting ids in the context
      #   of an org, this will the the chef_guid db, for global objects (users,
      #   global groups) this will be the opscode_account database
      # * user_mapper::: An Opscode::Mappers::User object
      # * client_mapper::: either an Opscode::Mappers::Client object, or nil
      #   when mapping ids outside of the context of an org (where there will not
      #   be any clients).
      # * clients_in_sql::: boolean.
      #--
      # NB: The implementation here of ignoring clients for global objects is
      # ugly; we need more clarity and explicitness around how we deal with
      # global vs. non-global objects.
      def initialize(couch_db, user_mapper, client_mapper=nil, clients_in_sql=false)
        @group_authz_ids_by_name = {}
        @group_names_by_authz_id = {}

        @actor_authz_ids_by_name = {}
        @actor_names_by_authz_id = {}

        @couch_db = couch_db
        @user_mapper = user_mapper
        @client_mapper = client_mapper
        @clients_in_sql = clients_in_sql
      end

      def actor_authz_ids_to_names(actor_ids)
        users = users_by_authz_ids(actor_ids)
        remaining_actors = actor_ids - users.map(&:authz_id)

        clients = clients_by_authz_ids(remaining_actors)
        actor_names = {:users => users.map(&:name), :clients => clients.map(&:name)}
        Mixlib::Authorization::Log.debug { "Mapped actors #{actors.inspect} to users #{actor_names}" }
        actor_names
      end

      def group_authz_ids_to_names(group_ids)
        group_ids.map {|group_id| group_authz_id_to_name(group_id)}.compact
      end

      def client_names_to_authz_ids(client_names)
        if clients_in_sql?
          return [] if @client_mapper.nil?

          clients = client_mapper.find_all_for_authz_map(client_names)
          unless clients.size == client_names.size
            missing_client_names = client_names - clients.map(&:name)
            raise InvalidGroupMember, "Users #{missing_user_names.join(', ')} do not exist"
          end
          clients.each {|c| cache_actor_mapping(c.name, c.authz_id)}
          clients.map(&:authz_id)
        else
          client_names.map do |clientname|
            unless client = Models::Client.on(couch_db).by_clientname(:key=>clientname).first
              raise InvalidGroupMember, "Client #{clientname} does not exist"
            end
            cache_actor_mapping(client.name, client.authz_id)
            client.authz_id
          end
        end
      end

      def user_names_to_authz_ids(user_names)
        users = user_mapper.find_all_for_authz_map(user_names)
        unless users.size == user_names.size
          missing_user_names = user_names - users.map(&:name)
          raise InvalidGroupMember, "Users #{missing_user_names.join(', ')} do not exist"
        end
        users.each {|u| cache_actor_mapping(u.name, u.authz_id) }
        users.map {|u| u.authz_id}
      end

      def group_names_to_authz_ids(group_names)
        group_names.map {|g| group_name_to_authz_id(g)}
      end

      def clients_in_sql?
        @clients_in_sql
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

      def clients_by_authz_ids(authz_ids)
        if clients_in_sql?
          return [] if @client_mapper.nil?
          clients = @client_mapper.find_all_by_authz_id(authz_ids)
          clients.each {|c| cache_actor_mapping(c.name, c.authz_id)}
          clients
        else
          authz_ids.map {|authz_id| client_by_authz_id_couch(authz_id) }.compact
        end
      end

      def client_by_authz_id_couch(client_authz_id)
        if name = @actor_names_by_authz_id[client_authz_id]
          name
        elsif client_join_entry = AuthJoin.by_auth_object_id(:key=>client_authz_id).first
          client = Mixlib::Authorization::Models::Client.on(couch_db).get(client_join_entry.user_object_id)
          cache_actor_mapping(client.name, client_authz_id)
          client
        else
          nil
        end
      end

      def group_name_to_authz_id(group_name)
        if authz_id = @group_authz_ids_by_name[group_name]
          authz_id
        elsif group = Models::Group.on(couch_db).by_groupname(:key=>group_name).first
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
          name = Mixlib::Authorization::Models::Group.on(couch_db).get(auth_join.user_object_id).groupname
          cache_group_mapping(name, authz_id)
          name
        else
          nil
        end
      end
    end

  end
end

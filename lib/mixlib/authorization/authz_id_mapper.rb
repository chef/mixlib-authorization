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
      attr_reader :client_mapper

      def clients_in_sql?
        @clients_in_sql
      end

      # Create a new AuthzIDMapper.  This is responsible for mapping
      # Authz-side identifiers to user-side names, and vice versa.
      # Depending on how it is parameterized, it can map global-level
      # information (e.g. Users), or org-scoped (e.g. Clients).
      #
      # @param couch_db {A CouchRest database} When converting ids in
      #   the context of an org, this will the the chef_guid db, for
      #   global objects (users, global groups) this will be the
      #   opscode_account database
      #
      # @param user_mapper [Opscode::Mappers::User] Note that users
      #   are exclusively stored in SQL datastores, so locality-aware
      #   mapping does not need to exist for them.
      #
      # @param client_mapper [Opscode::Mappers::Client, nil] When
      #   mapping global-scoped ids outside of the context of an org,
      #   there will not be any clients, and so this parameter can be
      #   `nil`.
      #
      # @param clients_in_sql [Boolean] When mapping in an org-scoped
      #   context, clients can be found in either CouchDB or SQL,
      #   depending on the migration status of the organization.  This
      #   should be determined by querying XDarkLaunch in the
      #   opscode-account layer, and passing the result in here.
      #
      # @note The implementation here of ignoring clients for global
      #   objects is ugly; we need more clarity and explicitness
      #   around how we deal with global vs. non-global objects.
      #
      # @todo Create a refactored initializer (or some equivalent
      #   scheme) that allows you to explicitly create either a global
      #   or an org-scoped mapper, instead of relying on client code
      #   to know the correct combination of parameters.
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

      # Given a list of Authz IDs, resolve the user-side names of the
      # Users and Clients represented by those IDs.
      #
      # @example Basic Usage
      #   actor_authz_ids_to_names(['deadbeefdeadbeefdeadbeefdeadbeef',
      #                             'abcd1234abcd1234abcd1234abcd1234'])
      #     => {:users => ['Mr. Dead Beef'],
      #         :clients => ['alphabet-validator']}
      #
      # @param actor_ids [Array<String>] a list of Authz IDs
      # @return [Hash<Symbol, Array<String>>] mapping of `:users` or
      #   `:clients` to arrays of names.
      def actor_authz_ids_to_names(actor_ids)
        users = users_by_authz_ids(actor_ids)
        remaining_actors = actor_ids - users.map(&:authz_id)
        client_names = client_authz_ids_to_names(remaining_actors)

        actor_names = {
          :users => users.map(&:name),
          :clients => client_names
        }

        Mixlib::Authorization::Log.debug { "Mapped actors #{actor_ids.inspect} to actors #{actor_names}" }

        # Some callers seem to want a hash back from this (like
        # Mixlib::Authorization::Models::Group#translate_actors_to_user_side!);
        # others (like Mixlib::Authorization::Acl#to_user) need just a
        # flat list
        #
        # For now, just return the hash (since the Acl case is a new
        # use), and make client code do the necessary transformation.

        # If additional places need a flat list, then consider a
        # broader refactoring.
        actor_names
      end

      # Given a list of actor names, resolve the Authz IDs of Users
      # and Clients represented by those names.  Checks to see if
      # names correspond to a User first, then a Client.
      #
      # @param actor_names [Array<String>]
      # @return [Array<String>>]
      def actor_names_to_authz_ids(actor_names)
        users = users_by_names(actor_names)
        remaining_actors = actor_names - users.map(&:name)
        client_ids = client_names_to_authz_ids(remaining_actors)
        user_ids = users.map(&:authz_id)

        Mixlib::Authorization::Log.debug { "Mapped actors #{actor_names.inspect} to users #{user_ids.inspect} and clients #{client_ids.inspect}" }
        user_ids + client_ids
      end

      # Fetches {Opscode::Model::User} objects corresponding to the
      # given `authz_ids`.  The number of {Opscode::Model::User}
      # objects returned may be less than the number of Authz IDs
      # given, since some IDs may actually correspond to Clients.
      #
      # Additionally caches the name->id mapping for use elsewhere.
      #
      # @param authz_ids [Array<String>]
      # @return [Array<Opscode::Models::User>]
      #
      # @see {#actor_authz_ids_to_names}
      # @see {#cache_actor_mapping}
      def users_by_authz_ids(authz_ids)
        users = @user_mapper.find_all_by_authz_id(authz_ids)
        users.each {|u| cache_actor_mapping(u.name, u.authz_id)}
        users
      end

      # @deprecated use {#users_by_names}.  This assumes that all
      #   given names are indeed for Users, and not for Clients as
      #   well.  Throwing an error in that case would be bad.  I'm
      #   going to leave this here for now, though, since its only
      #   used by
      #   Mixlib::Authorization::Models::Group#translate_ids_to_authz;
      #   in that case, it really should only have Users.  This can
      #   wait for another refactoring.
      #
      # @param user_names [Array<String>]
      # @return [Array<String>]
      def user_names_to_authz_ids(user_names)
        users = user_mapper.find_all_for_authz_map(user_names)
        unless users.size == user_names.size
          missing_user_names = user_names - users.map(&:name)
          raise InvalidGroupMember, "Users #{missing_user_names.join(', ')} do not exist"
        end
        users.each {|u| cache_actor_mapping(u.name, u.authz_id) }
        users.map {|u| u.authz_id}
      end

      # Favor this over user_names_to_authz_ids, since it fails to account for clients

      # Given a list of names, map them to the Authz IDs of the
      # corresponding users.  May return a list that is smaller than
      # `user_names`, since we're probably processing a list of
      # actors, which may include clients.
      #
      # @param user_names [Array<String>]
      # @return [Array<Opscode::Model::User>]
      def users_by_names(user_names)
        users = @user_mapper.find_all_for_authz_map(user_names)
        # TODO: I think we can dispense with the caching here since we're coming from SQL
        users.each{|u| cache_actor_mapping(u.name, u.authz_id)}
        users
      end

      # @param authz_ids [Array<String>]
      # @return [Array<String>] the names of clients corresponding to the given `authz_ids`
      def client_authz_ids_to_names(authz_ids)

        if clients_in_sql?
          # If the client mapper is nil, then we're probably dealing
          # with a "global" mapper, in which case there aren't going
          # to be clients anyway (since those are strictly org-scoped)
          return [] if @client_mapper.nil?

          # Otherwise, we're in an org-scoped mapper
          clients = @client_mapper.find_all_by_authz_id(authz_ids)
          # TODO: I think we can dispense with the caching here since we're coming from SQL
          clients.each {|c| cache_actor_mapping(c.name, c.authz_id)}
          client.map(&:name)
        else
          # This also performs the caching of client mappings.
          authz_ids.map {|authz_id| client_by_authz_id_couch(authz_id) }.compact
        end
      end

      # Get the *NAME* of a client specified by the given Authz ID.
      #
      # @param client_authz_id [String] the Authz ID of a Client to fetch
      #
      # @return [String, nil] The name of the client with the given
      #   authz ID.  Can return `nil` if the AuthzIDMapper is a "global"
      #   one, in which case, there won't ever be clients
      #
      # @todo Why would we even call this in a global mapper??
      def client_by_authz_id_couch(client_authz_id)
        # If we've already encountered the Client in CouchDB before,
        # use the cached value to prevent unnecessary HTTP requests.
        if name = @actor_names_by_authz_id[client_authz_id]
          name
        elsif client_join_entry = AuthJoin.by_auth_object_id(:key=>client_authz_id).first
          client = Mixlib::Authorization::Models::Client.on(couch_db).get(client_join_entry.user_object_id)
          cache_actor_mapping(client.name, client_authz_id)
          client.name
        else
          # Wasn't cached, and doesn't exist in the database.  This
          # can happen when this AuthzIDMapper is a "global" one, in
          # which case its @couch_db member will be pointing to the
          # opscode_account database, which won't have any clients in
          # it.
          nil
        end
      end

      # @return [Array<String>] the Authz IDs that correspond to the given client names
      def client_names_to_authz_ids(client_names)
        if clients_in_sql?
          return [] if @client_mapper.nil?

          clients = client_mapper.find_all_for_authz_map(client_names)
          unless clients.size == client_names.size
            missing_client_names = client_names - clients.map(&:name)
            raise InvalidGroupMember, "Clients #{missing_client_names.join(', ')} do not exist"
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

      def group_authz_ids_to_names(group_ids)
        group_ids.map {|group_id| group_authz_id_to_name(group_id)}.compact
      end

      def group_names_to_authz_ids(group_names)
        group_names.map {|g| group_name_to_authz_id(g)}
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

      private


      # These caches are only used for CouchDB clients and groups.
      # Users are stored in SQL, and the query overhead for that is
      # much less than it is for CouchDB

      def cache_actor_mapping(name, authz_id)
        @actor_names_by_authz_id[authz_id] = name
        @actor_authz_ids_by_name[name] = authz_id
      end

      def cache_group_mapping(name, authz_id)
        @group_names_by_authz_id[authz_id] = name
        @group_authz_ids_by_name[name] = authz_id
      end

    end

  end
end

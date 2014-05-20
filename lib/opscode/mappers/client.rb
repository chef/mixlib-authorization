require 'opscode/mappers/base'
require 'opscode/models/client'

module Opscode
  module Mappers
    class Client < Base

      class CannotDeleteValidator < ArgumentError
      end

      # Convenience class for initializing Mappers::Client objects:
      # * db::: Sequel database connection
      # * amqp::: Chef AMQP client
      # * org_id::: Organization GUID
      # * stats_client::: statsd client
      # * authz_id::: AuthZ id of the actor making the request
      class MapperConfig < Struct.new(:db, :amqp, :org_id, :stats_client, :authz_id)
      end

      attr_reader :amqp_connection
      attr_reader :org_id

      # Instantiate a Mappers::Client. Arguments are supplied by passing a
      # block, which yields a MapperConfig object. Example:
      #     Opscode::Mappers::Client.new do |m|
      #       m.db = Sequel.connect("mysql2:// ...")
      #       m.amqp = Chef::AmqpClient.instance
      #       m.org_id = "fffffff ..."
      #       m.stats_client = request.env['statsd.service.client'] # we use statsd via middleware
      #       m.authz_id = "123defffff ..."
      #     end
      # All attributes of the MapperConfig are required.
      def initialize
        conf = MapperConfig.new
        if block_given?
          yield conf
        end

        super(conf.db, conf.stats_client, conf.authz_id)

        @amqp_connection = conf.amqp
        @org_id = conf.org_id

        @table = @connection[:clients].filter(:org_id => org_id)
      end

      # These next methods were borrowed from Opscode::Mappers::User, and
      # do pretty much the same thing they did there.

      def find_all_for_authz_map(client_names)
        return client_names if client_names.empty?
        finder = @table.select(:id,:authz_id,:name).where(:name => client_names)
        execute_sql(:read, :clients) { finder.map {|c| inflate_model(c)}}
      end

      def find_all_by_authz_id(authz_ids)
        return authz_ids if authz_ids.empty?
        finder = table.select(:id,:authz_id,:name).where(:authz_id => authz_ids)
        execute_sql(:read, :clients) { finder.map {|c| inflate_model(c)}}
      end

      # Does all the work of creating a client: generates ids for it,
      # updates the timestamps, creates the object in authz, and
      def create(client, container)
        # If the caller has already set an id, trust it.
        client.assign_id!(new_uuid) unless client.id
        client.assign_org_id!(@org_id)
        client.update_timestamps!
        client.last_updated_by!(requester_authz_id)

        validate_before_create!(client)

        unless client.authz_id
          client.create_authz_object_as(requester_authz_id)
          # Do the container inheritance dance.
          # we rely on spoofing the request for the container's
          # ACLs as pivotal until authz is updated to allow ACL reads
          # to actors w/ create permissions.
          container_authz_doc = container.authz_object_as(container[:requester_id])
          client.authz_object_as(requester_authz_id).apply_parent_acl(container_authz_doc)
          grant_validator_permissions(client, container_authz_doc) if client.validator?
        end

        user_side_create(client) do
          update_index(client)
        end

        client.persisted!
        client
      end

      def validate_before_create!(client)
        client.valid?
        unless client.name.nil? || client.name.empty?
          if existing_client?(client)
            client.name_not_unique!
          end
        end

        unless client.errors.empty?
          self.class.invalid_object!(client.errors.full_messages.join(", "))
        end
      end

      def grant_validator_permissions(client, container_authz_doc)
        # Add validator to the ACES on "clients" container
        container_authz_doc.grant_permission_to_actor("create", client.authz_id)
        container_authz_doc.grant_permission_to_actor("read", client.authz_id)
        true
      end

      # Creates +client+ in the user side database. **DOES NOT** submit +client+
      # for indexing or create it in authz. Normally you should use the #create
      # call which does these things for you.
      #
      # The SQL insert is wrapped in a transaction; If you pass a code block to
      # this method, the block is called inside the transaction, and if the
      # block raises an error, the transaction is rolled back. #create uses
      # this to abort creation if the +client+ cannot be added to the search
      # index.
      def user_side_create(client)
        client_hash = client.for_db
        client_row = map_to_row!(client_hash)

        execute_sql(:create, :client) do
          @connection.transaction do
            yield if block_given?
            table.insert(client_row)
          end
        end
      end

      def update(client)
        unless client.id
          self.class.invalid_object!("Cannot save client #{client.name} without a valid id")
        end

        validate_before_update!(client)

        client.update_timestamps!
        row_data = map_to_row!(client.for_db)

        execute_sql(:update, :client) do
          @connection.transaction do
            update_index(client)
            table.filter(:id => client.id).update(row_data)
          end
        end
      rescue Sequel::DatabaseError => e
        log_exception("User update failed", e)
        self.class.query_failed!(e.message)
      end

      def validate_before_update!(client)
        client.valid?

        # Detect if we're updating the name to a value that's already in use:
        unless client.name.nil? || client.name.empty?
          existing_ids = execute_sql(:validate, :client) do
            finder = table.select(:id).filter(:name => client.name)
            finder.map {|row| row[:id]}
          end
          if existing_ids.any? {|id| id != client.id}
            client.name_not_unique!
          end
        end

        unless client.errors.empty?
          self.class.invalid_object!(client.errors.full_messages.join(", "))
        end
      end

      def update_index(client)
        publish_object(client.id, client.for_index)
      end

      def destroy(client)
        unless client.id
          self.class.invalid_object!("Cannot destroy client #{client.name} without a valid id")
        end

        if client.validator? && (validator_count <= 1)
          raise CannotDeleteValidator, "#{client.name} is the only validator in this organization, not deleting it."
        end

        unless execute_sql(:validate, :client) { table.select(:id).filter(:id => client.id).any? }
          raise RecordNotFound, "Can't delete client #{client.name} because it doesn't exist"
        end

        execute_sql(:delete, :client) { table.filter(:id => client.id).delete }
      end

      def list
        finder = @table.select(:name)
        execute_sql(:list, :client) { finder.all }.map {|row| row[:name]}
      end

      def find_by_name(name)
        row = execute_sql(:read, :client) { table.filter(:name => name).first }
        row && inflate_model(row)
      end

      def inflate_model(row_data)
        client = Models::Client.load(map_from_row!(row_data))
        client.persisted!
        client
      end

      # Properties of an Opscode::Model::Client object that have their
      # own columns in the database.  Leaving out 'admin', since
      # that's only applicable on Open Source Chef, which doesn't use
      # mixlib-authorization anyway.
      BREAKOUT_COLUMNS = [:id, :org_id, :authz_id, :name, :public_key,
                          :validator, :last_updated_by, :created_at, :updated_at]

      # Map the nested hash with serialized attributes that we store in DB rows
      # to a flat hash suitable for passing to Opscode::Model::Client's initializer
      def map_from_row!(row_data)
        model_data = {}
        case row_data.delete(:pubkey_version)
        when 0
          model_data[:public_key] = row_data.delete(:public_key)
        when 1
          model_data[:certificate] = row_data.delete(:public_key)
        when nil
          row_data.delete(:public_key) # just in case
        else
          raise ArgumentError, "Unknown public key version!  Client data was: #{row_data.inspect}"
        end

        BREAKOUT_COLUMNS.each do |property_name|
          model_data[property_name] = row_data.delete(property_name) if row_data.key?(property_name)
        end

        #Merb.logger.info("Client Model Data is: #{model_data}")

        model_data
      end

      def map_to_row!(model_data)
        if certificate = model_data.delete(:certificate)
          model_data[:pubkey_version] = 1
          model_data[:public_key] = certificate
        else
          model_data[:pubkey_version] = 0
        end
        model_data
      end

      # Client doesn't have a lot of extra marginally useful data,
      # so we'll return the whole thing when you look it up for authN
      alias :find_for_authentication :find_by_name

      private

      def existing_client?(client)
        execute_sql(:validate, :client) do
          table.select(:name).filter(:name => client.name).any?
        end
      end

      # Uses the amqp_client to update the object's queue. Hard codes use of AMQP transactions.
      def publish_object(object_id, object)
        amqp_connection.transaction do
          amqp_connection.queue_for_object(object_id) do |queue|
            queue.publish(as_json(object), :persistent => true)
          end
        end

        true
      end

      def validator_count
        execute_sql(:validate, :client) { table.filter(:validator => true).count }
      end

    end
  end
end

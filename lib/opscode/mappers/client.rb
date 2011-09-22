require 'opscode/mappers/base'

module Opscode
  module Mappers
    class Client < Base

      # Convenience class for initializing Mappers::Client objects:
      # * db::: Sequel database connection
      # * amqp::: Chef AMQP client
      # * org_id::: Organization GUID
      # * stats_client::: statsd client
      # * authz_id::: AuthZ id of the actor making the request
      class MapperConfig < Struct.new(:db, :amqp, :org_id, :stats_client, :authz_id)
        def valid?
          not values.any?(&:nil?)
        end
      end

      attr_reader :amqp_connection
      attr_reader :org_id

      # Instantiate a Mappers::Client. Arguments are supplied by passing a
      # block, which yields a MapperConfig object. Example:
      #     Opscode::Mappers::Client.new do |m|
      #       m.db = Sequel.connect("mysql2:// ...")
      #       m.ampq = Chef::AmqpClient.instance
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
        unless conf.valid?
          raise ArgumentError, "You must set all of #{conf.members.join(',')} via a block."
        end

        super(conf.db, conf.stats_client, conf.authz_id)

        @amqp_connection = conf.amqp
        @org_id = conf.org_id

        @table = @connection[:clients].filter(:org_id => org_id)
      end

      # Does all the work of creating a client: generates ids for it, updates the timestamps, creates the object in authz, and 
      def create(client, container)
        raise "TODO"
        # If the caller has already set an id, trust it.
        client.assign_id!(new_uuid) unless client.id
        client.assign_org_id!(@org_id)
        client.update_timestamps!
        client.last_updated_by!(requester_authz_id)

        unless client.authz_id
          client.create_authz_object_as(requester_authz_id) 
          client.authz_object_as(requester_authz_id).apply_container_acl(container)
        end

        user_side_create(client) do
          update_index(client)
        end

        client.persisted!
        client
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
        raise "TODO"
        client_hash = client.for_db

        execute_sql(:create, :client) do
          @connection.transaction do
            yield if block_given?
            table.insert(client_hash)
          end
        end
      end

      def update(client)
        raise "TODO"
        unless client.id
          self.class.invalid_object!("Cannot save client #{client.name} without a valid id")
        end

        client.update_timestamps!
        client_hash = client.for_db
        client_hash.delete(:client_data)
        client_hash[:serialized_object] ||= client.for_json

        execute_sql(:update, :client) { table.filter(:id => client.id).update(client_hash) }
      rescue Sequel::DatabaseError => e
        log_exception("User update failed", e)
        self.class.query_failed!(e.message)
      end

      def update_index(client)
        publish_object(client.id, client.for_indexing)
      end

      def destroy(client)
        raise "TODO"
        unless client.id
          self.class.invalid_object!("Cannot destroy client #{client.name} without a valid id")
        end

        unless execute_sql(:validate, :client) { table.select(:id).filter(:id => client.id).any? }
          raise RecordNotFound, "Can't delete client #{client.name} because it doesn't exist"
        end

        execute_sql(:delete, :client) { table.filter(:id => user.id).delete }
      end

      def list
        finder = @table.select(:name)
        execute_sql(:list, :client) { finder.all }.map {|row| row[:name]}
      end

      def find_by_name(name)
        nil
      end

      # Client doesn't have a lot of extra marginally useful data,
      # so we'll return the whole thing when you look it up for authN
      alias :find_for_authentication :find_by_name

      private

      # Uses the amqp_client to update the object's queue. Hard codes use of AMQP transactions.
      def publish_object(object_id, object)
        amqp_connection.transaction do
          amqp_connection.queue_for_object(object_id) do |queue|
            queue.publish(as_json(object), :persistent => true)
          end
        end

        true
      end

    end
  end
end


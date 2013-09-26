require 'opscode/mappers/base'
require 'opscode/models/container'

module Opscode
  module Mappers
    class Container < Base

      # Convenience class for initializing Mappers::Container objects:
      # * db::: Sequel database connection
      # * amqp::: Chef AMQP client
      # * org_id::: Organization GUID
      # * stats_client::: statsd client
      # * authz_id::: AuthZ id of the actor making the request
      class MapperConfig < Struct.new(:db, :org_id, :stats_client, :authz_id)
      end

      attr_reader :org_id

      # Instantiate a Mappers::Container. Arguments are supplied by passing a
      # block, which yields a MapperConfig object. Example:
      #     Opscode::Mappers::Client.new do |m|
      #       m.db = Sequel.connect("mysql2:// ...")
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

        @org_id = conf.org_id
        @table = @connection[:containers].filter(:org_id => @org_id)
      end

      # Does all the work of creating a container: generates ids for it,
      # updates the timestamps, creates the object in authz, and
      def create(container)
        # If the caller has already set an id, trust it.
        container.assign_id!(new_uuid) unless container.id
        container.assign_org_id!(@org_id)
        container.update_timestamps!
        container.last_updated_by!(requester_authz_id)

        validate_before_create!(container)

        unless container.authz_id
          container.create_authz_object_as(requester_authz_id)
        end

        user_side_create(container)

        container.persisted!
        container
      end

      def validate_before_create!(container)
        container.valid?
        unless container.name.nil? || container.name.empty?
          if existing_container?(container)
            container.name_not_unique!
          end
        end

        unless container.errors.empty?
          self.class.invalid_object!(container.errors.full_messages.join(", "))
        end
      end

      # Creates +container+ in the user side database. **DOES NOT** submit +container+
      # for indexing or create it in authz. Normally you should use the #create
      # call which does these things for you.
      #
      # The SQL insert is wrapped in a transaction; If you pass a code block to
      # this method, the block is called inside the transaction, and if the
      # block raises an error, the transaction is rolled back. #create uses
      # this to abort creation if the +container+ cannot be added to the search
      # index.
      def user_side_create(container)
        container_hash = container.for_db
        container_row = map_to_row!(container_hash)

        execute_sql(:create, :container) do
          @connection.transaction do
            yield if block_given?
            table.insert(container_row)
          end
        end
      end

      def update(container)
        unless container.id
          self.class.invalid_object!("Cannot save container #{container.name} without a valid id")
        end

        validate_before_update!(container)

        container.update_timestamps!
        row_data = map_to_row!(container.for_db)

        execute_sql(:update, :container) do
          @connection.transaction do
            table.filter(:id => container.id).update(row_data)
          end
        end
      rescue Sequel::DatabaseError => e
        log_exception("User update failed", e)
        self.class.query_failed!(e.message)
      end

      def validate_before_update!(container)
        container.valid?

        # Detect if we're updating the name to a value that's already in use:
        unless container.name.nil? || container.name.empty?
          existing_ids = execute_sql(:validate, :container) do
            finder = table.select(:id).filter(:name => container.name)
            finder.map {|row| row[:id]}
          end
          if existing_ids.any? {|id| id != container.id}
            container.name_not_unique!
          end
        end

        unless container.errors.empty?
          self.class.invalid_object!(container.errors.full_messages.join(", "))
        end
      end

      def destroy(container)
        unless container.id
          self.class.invalid_object!("Cannot destroy container #{container.name} without a valid id")
        end

        unless execute_sql(:validate, :container) { table.select(:id).filter(:id => container.id).any? }
          raise RecordNotFound, "Can't delete container #{container.name} because it doesn't exist"
        end

        execute_sql(:delete, :container) { table.filter(:id => container.id).delete }
      end

      def list
        finder = @table.select(:name)
        execute_sql(:list, :container) { finder.all }.map {|row| row[:name]}
      end

      def find_by_name(name)
        row = execute_sql(:read, :container) { table.filter(:name => name).first }
        row && inflate_model(row)
      end

      def inflate_model(row_data)
        container = Models::Container.load(map_from_row!(row_data))
        container.persisted!
        container
      end

      # Properties of an Opscode::Model::Container object that have their
      # own columns in the database.  Leaving out 'admin', since
      # that's only applicable on Open Source Chef, which doesn't use
      # mixlib-authorization anyway.
      BREAKOUT_COLUMNS = [:id, :org_id, :authz_id, :name, :last_updated_by, :created_at, :updated_at]

      # Map the nested hash with serialized attributes that we store in DB rows
      # to a flat hash suitable for passing to Opscode::Model::Container's initializer
      def map_from_row!(row_data)
        model_data = {}

        BREAKOUT_COLUMNS.each do |property_name|
          model_data[property_name] = row_data.delete(property_name) if row_data.key?(property_name)
        end

#        Merb.logger.info("Container Model Data is: #{model_data}")

        model_data
      end

      def map_to_row!(model_data)
#        model_data[:last_updated_by] = requester_aid
        model_data
      end

      # Container doesn't have a lot of extra marginally useful data,
      # so we'll return the whole thing when you look it up for authN
      alias :find_for_authentication :find_by_name

      private

      def existing_container?(container)
        execute_sql(:validate, :container) do
          table.select(:name).filter(:name => container.name).any?
        end
      end

      def validator_count
        execute_sql(:validate, :client) { table.filter(:validator => true).count }
      end

    end
  end
end

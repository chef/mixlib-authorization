require 'opscode/mappers/base'
require 'opscode/models/group'

module Opscode
  module Mappers
    class Group < Base

      # Convenience class for initializing Mappers::Group objects:
      # * db::: Sequel database connection
      # * amqp::: Chef AMQP client
      # * org_id::: Organization GUID
      # * stats_client::: statsd client
      # * authz_id::: AuthZ id of the actor making the request
      class MapperConfig < Struct.new(:db, :org_id, :stats_client, :authz_id)
      end

      attr_reader :org_id

      # Instantiate a Mappers::Group. Arguments are supplied by passing a
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
        @table = @connection[:groups].filter(:org_id => @org_id)
      end

      # Does all the work of creating a group: generates ids for it,
      # updates the timestamps, creates the object in authz, and
      def create(group)
        # If the caller has already set an id, trust it.
        group.assign_id!(new_uuid) unless group.id
        group.assign_org_id!(@org_id)
        group.update_timestamps!
        group.last_updated_by!(requester_authz_id)

        validate_before_create!(group)

        unless group.authz_id
          group.create_authz_object_as(requester_authz_id)
        end

        user_side_create(group)

        group.persisted!
        group
      end

      def validate_before_create!(group)
        group.valid?
        unless group.name.nil? || group.name.empty?
          if existing_group?(group)
            group.name_not_unique!
          end
        end

        unless group.errors.empty?
          self.class.invalid_object!(group.errors.full_messages.join(", "))
        end
      end

      # Creates +group+ in the user side database. **DOES NOT** create group in
      # authz. Normally you should use the #create call which does these things
      # for you.
      #
      # The SQL insert is wrapped in a transaction; If you pass a code block to
      # this method, the block is called inside the transaction, and if the
      # block raises an error, the transaction is rolled back. #create uses
      # this to abort creation if the +group+ cannot be added to the search
      # index.
      def user_side_create(group)
        group_hash = group.for_db
        group_row = map_to_row!(group_hash)

        execute_sql(:create, :group) do
          @connection.transaction do
            yield if block_given?
            table.insert(group_row)
          end
        end
      end

      def update(group)
        unless group.id
          self.class.invalid_object!("Cannot save group #{group.name} without a valid id")
        end

        validate_before_update!(group)

        group.update_timestamps!
        row_data = map_to_row!(group.for_db)

        execute_sql(:update, :group) do
          @connection.transaction do
            table.filter(:id => group.id).update(row_data)
          end
        end
      rescue Sequel::DatabaseError => e
        log_exception("User update failed", e)
        self.class.query_failed!(e.message)
      end

      def validate_before_update!(group)
        group.valid?

        # Detect if we're updating the name to a value that's already in use:
        unless group.name.nil? || group.name.empty?
          existing_ids = execute_sql(:validate, :group) do
            finder = table.select(:id).filter(:name => group.name)
            finder.map {|row| row[:id]}
          end
          if existing_ids.any? {|id| id != group.id}
            group.name_not_unique!
          end
        end

        unless group.errors.empty?
          self.class.invalid_object!(group.errors.full_messages.join(", "))
        end
      end

      def destroy(group)
        unless group.id
          self.class.invalid_object!("Cannot destroy group #{group.name} without a valid id")
        end

        unless execute_sql(:validate, :group) { table.select(:id).filter(:id => group.id).any? }
          raise RecordNotFound, "Can't delete group #{group.name} because it doesn't exist"
        end

        execute_sql(:delete, :group) { table.filter(:id => group.id).delete }
      end

      def list
        finder = @table.select(:name)
        execute_sql(:list, :group) { finder.all }.map {|row| row[:name]}
      end

      def find_by_name(name)
        row = execute_sql(:read, :group) { table.filter(:name => name).first }
        row && inflate_model(row)
      end

      def inflate_model(row_data)
        group = Models::Group.load(map_from_row!(row_data))
        group.persisted!
        group
      end

      # Properties of an Opscode::Model::Group object that have their
      # own columns in the database.  Leaving out 'admin', since
      # that's only applicable on Open Source Chef, which doesn't use
      # mixlib-authorization anyway.
      BREAKOUT_COLUMNS = [:id, :org_id, :authz_id, :name, :last_updated_by, :created_at, :updated_at]

      # Map the nested hash with serialized attributes that we store in DB rows
      # to a flat hash suitable for passing to Opscode::Model::Group's initializer
      def map_from_row!(row_data)
        model_data = {}

        BREAKOUT_COLUMNS.each do |property_name|
          model_data[property_name] = row_data.delete(property_name) if row_data.key?(property_name)
        end

#        Merb.logger.info("Group Model Data is: #{model_data}")

        model_data
      end

      def map_to_row!(model_data)
#        model_data[:last_updated_by] = requester_aid
        model_data
      end

      # Group doesn't have a lot of extra marginally useful data,
      # so we'll return the whole thing when you look it up for authN
      alias :find_for_authentication :find_by_name

      private

      def existing_group?(group)
        execute_sql(:validate, :group) do
          table.select(:name).filter(:name => group.name).any?
        end
      end

      def validator_count
        execute_sql(:validate, :client) { table.filter(:validator => true).count }
      end

    end
  end
end

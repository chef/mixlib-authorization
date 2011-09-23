require 'sequel'
require 'yajl'
require 'uuidtools'
require 'opscode/mappers/amqp_client_ext.rb'

# UTC4Life plz:
Sequel.default_timezone = :utc

module Opscode
  module Mappers

    class InvalidConfig < StandardError
    end

    # A connection string passed to Sequel.connect()
    #
    # Examples:
    # * "mysql2://root@localhost/opscode_chef"
    # * "mysql2://user:password@host/opscode_chef"
    # * "jdbc:mysql://localhost/test?user=root&password=root"
    #
    # See also: http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html
    def self.connection_string=(sequel_connection_string)
      @database.disconnect if @database.respond_to?(:disconnect)
      @database = nil
      @connection_string = sequel_connection_string
    end

    # Returns the connection string or raises an error if you didn't set one.
    def self.connection_string
      @connection_string or raise InvalidConfig, "No connection_string set for Opscode::Mappers"
    end

    # Returns a Sequel::Database object, which wraps access to the database.
    # Until sharding is required, this is where we keep the connection to the
    # one true database.
    #
    # NB: At the time of writing, some CouchRest based models access the
    # database via callbacks, which they can only do via de facto globals.
    def self.default_connection
      @database ||= Sequel.connect(connection_string, :max_connections => 2)
    end


    class InvalidRecord < ArgumentError
    end

    class RecordNotFound < ArgumentError
    end

    #== Opscode::Mappers::Base
    # Base class for the mappers. No actual behavior yet.
    class Base
      # Specify the Exception class to raise when an invalid object is given
      # for create/update. Defaults to RuntimeError
      def self.raise_on_invalid(exception_class)
        @invalid_object_exception = exception_class
      end

      # Specify the Exception class to raise when a database error occurs.
      # Defaults to ArgumentError
      def self.raise_on_error(exception_class)
        @db_error_exception = exception_class
      end

      def self.db_error_exception
        @db_error_exception || RuntimeError
      end

      def self.invalid_object_exception
        @invalid_object_exception || InvalidRecord
      end

      # Raise an error in response to an error from the database. By default,
      # this error is RuntimeError, but it can be customized, e.g., to raise a
      # Merb InternalServerError exception.
      def self.query_failed!(*args)
        raise db_error_exception, *args
      end

      # Raise an error in response to an error from the database. By default,
      # this is an Opscode::Mappers::InvalidRecord error. Though it _can_ be
      # customized, the current implementation of opscode account returns a 400
      # or 409 depending on how the model object is invalid...
      def self.invalid_object!(*args)
        raise invalid_object_exception, *args
      end

      # A Sequel Collection object representing the table
      attr_reader :table

      # A Sequel Database object
      attr_reader :connection

      # The Authorization side ID of the person making this request.
      # Recorded for debug/audit purposes.
      attr_reader :requester_authz_id

      # Create a new Mapper:
      # * database_connection::: A kind of Sequel::Database, as returned by
      #   Sequel.connect
      # * stats_client::: a Statsd::Client object, or nil for no stats. In
      #   general you should supply stats for production code, unless you have
      #   to workaround inflexible code.
      # * requester_authz_id::: The authz id of the actor making requests. This
      #   will be used when create/update/delete needs to make requests to
      #   authz--authz has its own internal authorization for requests. You can
      #   give 0 if you're only reading.
      #
      # NOTE: If you override this, make sure to set the @connection, @table,
      # @stats_client and @requester_authz_id instance variables
      def initialize(database_connection, stats_client, requester_authz_id)
        @connection = database_connection
        @table = @connection[:users]
        @stats_client = stats_client
        @requester_authz_id = requester_authz_id
      end

      def logger
        # TODO: less ghetto.
        @logger ||= Logger.new('/dev/null')
      end

      # Wraps the sql executing code in the given block with a single retry and
      # runs it. Also benchmarks the call. crud_operation and model are not yet
      # used, they're intended for future stats keeping.
      #
      # NB: This will break any transactions that are initiated outside of this
      # call if the operation fails and is retried.
      def execute_sql(crud_operation, model, should_retry=true, &sql_code)
        benchmark_db(crud_operation, model, &sql_code)
      rescue Sequel::DatabaseConnectionError
        if should_retry
          execute_sql(crud_operation, model, false, &sql_code)
        else
          raise
        end
      end

      # Benchmark the database operation done in the given block.
      # +crud_operation+ and +tags+ can be used to classify the operation.
      # +crud_operation+ should be one of :create, :read, :update, :delete
      def benchmark_db(crud_operation, model)
        if @stats_client
          @stats_client.db_call { yield }
        else
          yield
        end
      end

      # Log an exception. +where+ should be a descriptive message about which
      # operation failed, and +e+ is the actual exception object.
      def log_exception(where, e)
        logger.error "#{where}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      end

      # Generate a new UUID. Currently uses the v1 UUID scheme.
      def new_uuid
        UUIDTools::UUID.timestamp_create.hexdigest
      end

      private

      # Parse the portion of the object that's stored as a blob o' JSON
      def from_json(serialized_data)
        Yajl::Parser.parse(serialized_data, :symbolize_keys => true)
      end

      # Encode the portion of the object that's stored as a blob o' JSON
      def as_json(data)
        Yajl::Encoder.encode(data)
      end

    end

  end
end

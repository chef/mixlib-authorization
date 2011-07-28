require 'opscode/mappers/base'
require 'opscode/models/user'

module Opscode
  module Mappers
    class InvalidRecord < ArgumentError
    end

    class User

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

      # Set the default exception classes
      raise_on_invalid(InvalidRecord)
      raise_on_error(RuntimeError)


      def self.invalid_object!(*args)
        raise @invalid_object_exception, *args
      end

      # These properties of a Model::User have their own columns in the
      # database. There are also columns for cert/private key but these are
      # mapped in a special way.
      BREAKOUT_COLUMNS = [:id, :authz_id, :username, :email, :created_at, :updated_at, :last_updated_by]

      # A Sequel Collection object representing the table
      attr_reader :table

      # A Sequel Database object
      attr_reader :connection

      # The Authorization side ID of the person making this request.
      # Recorded for debug/audit purposes.
      attr_reader :requester_authz_id

      def initialize(database_connection, requester_authz_id)
        @connection = database_connection
        @table = @connection[:users]
        @requester_authz_id = requester_authz_id
      end

      def create(user)
        user.id ||= new_uuid
        user.update_timestamps!
        user.last_updated_by!(requester_authz_id)

        validate_before_create!(user)

        connection.transaction do
          user_side_create(user)
          # authz_side_create(user)
          # enqueue_for_indexing(user) # actually not, but this is where we would do it
        end
        user.persisted!
        user
      rescue Sequel::DatabaseError => e
        we = e.wrapped_exception
        pp [we.class.name, we.message, we.errno, we.sql_state, we.backtrace]
        pp [e.class.name, e.message, e.backtrace]
        false
      end

      def validate_before_create!(user)
        # Calling valid? will reset the error list :( so it has to be done first.
        user.valid?

        # NB: These uniqueness constraints have to be enforced by the database
        # also, or else there is a race condition. However, checking for them
        # separately allows us to give a better experience in the common
        # non-race failure conditions.
        unless (user.username.nil? || user.username.empty?)
          if benchmark_db(:validate, :user) { table.filter(:username => user.username).any? }
            user.username_not_unique!
          end
        end

        unless (user.email.nil? || user.email.empty?)
          if benchmark_db(:validate, :user) { table.filter(:email => user.email).any? }
            user.email_not_unique!
          end
        end

        unless user.errors.empty?
          self.class.invalid_object!(user.errors.full_messages.join(", "))
        end

        true
      end

      # Creates a row for the Models::User object +user+ in the database. In
      # typical use you will never call this directly, but it might be useful
      # in orgmapper or other diagnostic situations. In other words, let's
      # pretend this method is private.
      #
      # In addition to the above, note that this method DOES NOT validate the
      # user object before saving.
      def user_side_create(user)
        user_data = user.for_db
        row_data = map_to_row!(user_data)
        benchmark_db(:create, :user) { table.insert(row_data) }
      end

      # Returns a Models::User object containing *only* enough data to
      # authenticate a request from this user and authorize further actions.
      # The following properties *are* included:
      # * id
      # * authz_id
      # * username
      # * public_key or certificate
      #
      # The returned user object will probably be invalid for saving and
      # shouldn't be used to modify the user object.
      def find_for_authentication(username)
        finder = table.select(:id,:authz_id,:username, :pubkey_version,:public_key).where(:username => username)
        if user_data = benchmark_db(:read, :user) { finder.first }
          inflate_model(user_data)
        else
          nil
        end
      end

      # Returns a Models::User object with all properties set.
      def find_by_username(username)
        finder = table.where(:username => username)
        if user_data = benchmark_db(:read, :user) { finder.first }
          inflate_model(user_data)
        else
          nil
        end
      end

      def inflate_model(row_data)
        created_at = row_data[:created_at]
        user = Models::User.load(map_from_row!(row_data))
        user.persisted!
        user
      end

      # Map the "flat hash" representation of a User (as given by
      # Models::User.for_json) to the "database row" Hash format.
      #
      # This method destructively modifies its input.
      def map_to_row!(user_data)
        row_data = {}

        # Handle public_key vs. certificates
        if user_data.key?(:public_key)
          row_data[:pubkey_version] = 0
          row_data[:public_key] = user_data.delete(:public_key)
        else
          row_data[:pubkey_version] = 1
          row_data[:public_key] = user_data.delete(:certificate)
        end

        BREAKOUT_COLUMNS.each do |property_name|
          row_data[property_name] = user_data.delete(property_name) if user_data.key?(property_name)
        end

        row_data[:serialized_object] = as_json(user_data)
        row_data
      end

      # Map the nested hash with serialized attributes that we store in DB rows
      # to a flat hash suitable for passing to Model::User's initializer
      def map_from_row!(row_data)
        model_data = {}
        case row_data.delete(:pubkey_version)
        when 0
          model_data[:public_key] = row_data.delete(:public_key)
        when 1
          model_data[:certificate] = row_data.delete(:public_key)
        else
          raise ArguementError, "fetching a user w/o the public key is not supported yet."
        end

        if serialized_data = row_data.delete(:serialized_object)
          model_data.merge!(from_json(serialized_data))
        end

        BREAKOUT_COLUMNS.each do |property_name|
          model_data[property_name] = row_data.delete(property_name) if row_data.key?(property_name)
        end

        model_data
      end

      # Benchmark the database operation done in the given block.
      # +crud_operation+ and +tags+ can be used to classify the operation.
      # +crud_operation+ should be one of :create, :read, :update, :delete
      def benchmark_db(crud_operation, model)
        yield
      end

      def new_uuid
        UUIDTools::UUID.timestamp_create.hexdigest
      end

      def from_json(serialized_data)
        Yajl::Parser.parse(serialized_data, :symbolize_keys => true)
      end

      def as_json(data)
        Yajl::Encoder.encode(data)
      end

    end
  end
end

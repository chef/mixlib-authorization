require 'opscode/mappers/base'
require 'opscode/models/user'

module Opscode
  module Mappers
    class User < Base

      # These properties of a Model::User have their own columns in the
      # database. There are also columns for cert/private key and passwords
      # but these are # mapped in a special way.
      BREAKOUT_COLUMNS = [:id, :authz_id, :username, :email,
                          :external_authentication_uid,
                          :recovery_authentication_enabled, :created_at, :updated_at,
                          :last_updated_by]

      PASSWORD_COLUMNS = [:hashed_password, :salt, :hash_type]

      # Create a record in the database representing +user+ which is expected
      # to be a Models::User object.
      def create(user)
        # If the caller has already set an id, trust it.
        user.assign_id!(new_uuid) unless user.id
        user.update_timestamps!
        user.last_updated_by!(requester_authz_id)

        validate_before_create!(user)

        # If you say you know the authz id, then we trust that it already exists
        user.create_authz_object_as(requester_authz_id) unless user.authz_id
        user_side_create(user)
        user.persisted!
        user
      rescue Sequel::DatabaseError => e
        log_exception("User creation failed", e)
        self.class.query_failed!(e.message)
      end

      # Runs validations on +user+ and checks uniqueness constraints (currently
      # for username and email). If +user+ is not valid, invalid_object! will
      # be called, which by default will raise an InvalidRecord exception.
      def validate_before_create!(user)
        # Calling valid? will reset the error list :( so it has to be done first.
        user.valid?

        # NB: These uniqueness constraints have to be enforced by the database
        # also, or else there is a race condition. However, checking for them
        # separately allows us to give a better experience in the common
        # non-race failure conditions.
        unless (user.username.nil? || user.username.empty?)
          if execute_sql(:validate, :user) { table.select(:username).filter(:username => user.username).any? }
            user.username_not_unique!
          end
        end

        unless (user.email.nil? || user.email.empty?)
          if execute_sql(:validate, :user) { table.select(:email).filter(:email => user.email).any? }
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
        execute_sql(:create, :user) { table.insert(row_data) }
      end

      # Updates the row in the database representing +user+ which should be a
      # Models::User object. Note that the current code doesn't track which
      # attributes have been "dirtied" so the full object is saved every time.
      def update(user)
        unless user.id
          self.class.invalid_object!("Cannot save user #{user.username} without a valid id")
        end

        user.update_timestamps!

        validate_before_update!(user)

        execute_sql(:update, :user) { table.filter(:id => user.id).update(map_to_row!(user.for_db)) }
      rescue Sequel::DatabaseError => e
        log_exception("User update failed", e)
        self.class.query_failed!(e.message)
      end

      # Runs validations on +user+ and checks uniqueness constraints (currently
      # for username and email). If +user+ is not valid, invalid_object! will
      # be called, which by default will raise an InvalidRecord exception.
      #
      # The uniqueness constraints on users have to be checked a bit
      # differently than for create.
      def validate_before_update!(user)
        # Calling valid? will reset the error list :( so it has to be done first.
        user.valid?

        # NB: These uniqueness constraints have to be enforced by the database
        # also, or else there is a race condition. However, checking for them
        # separately allows us to give a better experience in the common
        # non-race failure conditions.
        unless (user.username.nil? || user.username.empty?) # these are covered by other validations
          existing_users_ids = execute_sql(:validate, :user) do
            table.select(:id).filter(:username => user.username).map {|u| u[:id]}
          end
          if existing_users_ids.any? {|id| id != user.id }
            user.username_not_unique!
          end
        end

        unless (user.email.nil? || user.email.empty?) # validated elsewhere
          existing_users_ids = execute_sql(:validate, :user) do
            table.select(:id).filter(:email => user.email).map {|u| u[:id]}
          end
          if existing_users_ids.any? {|id| id != user.id }
            user.email_not_unique!
          end
        end

        unless user.errors.empty?
          self.class.invalid_object!(user.errors.full_messages.join(", "))
        end

        true
      end

      # Deletes the row in the database representing +user+ which should be a
      # Models::User object.
      def destroy(user)
        unless user.id
          self.class.invalid_object!("Cannot save user #{user.username} without a valid id")
        end

        unless execute_sql(:validate, :user) { table.select(:id).filter(:id => user.id).any? }
          raise RecordNotFound, "Can't delete user #{user.username} because it doesn't exist"
        end

        execute_sql(:delete, :user) { table.filter(:id => user.id).delete }
      end

      # Generic finder wrapper that takes a block of Sequel filters
      def find_by_query(&block)
        finder = block ? block.call(table) : table
        if user_data = execute_sql(:read, :user) { finder.first }
          inflate_model(user_data)
        else
          nil
        end
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
        find_by_query do |table|
          table.select(:id,:authz_id,:username, :pubkey_version,:public_key).where(:username => username)
        end
      end

      # Returns a Models::User object with all properties set.
      def find_by_username(username)
        find_by_query do |table|
          table.where(:username => username)
        end
      end

      # Finds the user with +user_id+ and returns it with all properties
      def find_by_id(user_id)
        find_by_query do |table|
          table.where(:id => user_id)
        end
      end

      # Finds the user by the given +authz_id+ and returns it with the id, authz_id and username set.
      def find_by_authz_id(authz_id)
        find_by_query do |table|
          table.select(:id,:authz_id,:username).where(:authz_id => authz_id)
        end
      end

      # Finds the user by the given +external_authentication_uid+
      def find_by_external_authentication_uid(external_authentication_uid)
        finder = table.where(:external_authentication_uid => external_authentication_uid)
        if user_data = execute_sql(:read, :user) { finder.first }
          inflate_model(user_data)
        else
          nil
        end
      end

      def find_all_by_query(&block)
        execute_sql(:read, :user) { block.call(table).map {|u| inflate_model(u) } }
      end

      # Loads the entire set of users into memory. Don't do this in production code.
      def find_all
        execute_sql(:read, :user) { table.map {|u| inflate_model(u) } }
      end

      # Loads the full objects for all of the users in the list of +usernames+
      def find_all_by_username(usernames)
        finder = table.where(:username => usernames)
        execute_sql(:read, :user) { finder.map {|u| inflate_model(u) } }
      end

      # Finds the users by username, and returns it with the id, authz_id, and username set.
      def find_all_for_authz_map(usernames)
        return usernames if usernames.empty?
        finder = table.select(:id,:authz_id,:username).where(:username => usernames)
        execute_sql(:read, :user) { finder.map {|u| inflate_model(u)}}
      end

      def find_all_by_authz_id(authz_ids)
        return authz_ids if authz_ids.empty?
        finder = table.select(:id,:authz_id,:username).where(:authz_id => authz_ids)
        execute_sql(:read, :user) { finder.map {|u| inflate_model(u)}}
      end

      def find_all_by_id(ids)
        return ids if ids.empty?
        finder = table.select(:id,:authz_id,:username).where(:id => ids)
        execute_sql(:read, :user) { finder.map {|u| inflate_model(u)}}
      end

      # Returns a list of all usernames in the database as strings.
      def find_all_usernames
        execute_sql(:read, :user) do
          table.select(:username).map do |row|
            row[:username]
          end
        end
      end

      # Returns a list of all users in the database as Models::User objects.
      # The objects are "partially inflated" and contain the username, first
      # name, last name, and email address
      def find_all_for_support_ui
        execute_sql(:read, :user) do
          table.select(:username, :email, :serialized_object).map do |row|
            inflate_model(row)
          end
        end
      end


      # Converts a Hash of the form returned from a Sequel query into a
      # Models::User object. Not all fields need to be present (but of course
      # you don't want to save an object that has only partial data).
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

        breakout_columns(user_data).each do |property_name|
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
        when nil
          row_data.delete(:public_key) # just in case
        else
          raise ArgumentError, "Unknown public key version."
        end

        if serialized_data = row_data.delete(:serialized_object)
          model_data.merge!(from_json(serialized_data))
        end

        breakout_columns(row_data).each do |property_name|
          model_data[property_name] = row_data.delete(property_name) if row_data.key?(property_name)
        end

        model_data
      end

      # If we have someting in hash_type, then this SQL record has password
      # data deserialized. We want to use what is in the columns and ignore
      # password data in serialized_data, if any.
      def breakout_columns(authoritative_data)
        if authoritative_data[:hash_type]
          BREAKOUT_COLUMNS + PASSWORD_COLUMNS
        else
          BREAKOUT_COLUMNS
        end
      end


    end
  end
end

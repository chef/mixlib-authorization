require 'sequel'
require 'yajl'
require 'uuidtools'

# UTC4Life plz:
Sequel.default_timezone = :utc

module Opscode
  module Mappers

    class InvalidConfig < StandardError
    end

    # A more or less no-op query that's used to make sure the database
    # connection isn't dead.
    SELECT_1 = "SELECT 1;".freeze

    # A connection string passed to Sequel.connect()
    #
    # Examples:
    # * "mysql2://root@localhost/opscode_chef"
    # * "mysql2://user:password@host/opscode_chef"
    # * "jdbc:mysql://localhost/test?user=root&password=root"
    #
    # See also: http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html
    def self.connection_string=(sequel_connection_string)
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
      @database ||= Sequel.connect(connection_string)
    end

    # Sequel will reestablish connections to the database, but only after one
    # failed query. Since unicorn is pre-forking, that means we'll have a lot
    # of unicorn processes with dead connections to clear out after a
    # connection drop event. This method is a mitigation strategy for that
    # problem, where we issue a query at the beginning of a request to ensure a
    # valid connection.
    def self.cleanup_dead_connections(should_retry=true)
      default_connection.run(SELECT_1)
    rescue Sequel::DatabaseConnectionError
      raise unless should_retry
      cleanup_dead_connections(false)
    end

    #== Opscode::Mappers::Base
    # Base class for the mappers. No actual behavior yet.
    class Base
    end

  end
end

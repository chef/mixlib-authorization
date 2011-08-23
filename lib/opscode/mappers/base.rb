require 'sequel'
require 'yajl'
require 'uuidtools'

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

    #== Opscode::Mappers::Base
    # Base class for the mappers. No actual behavior yet.
    class Base
    end

  end
end

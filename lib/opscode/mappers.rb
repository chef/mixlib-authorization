module Opscode
  module Mappers
  end
end

require 'opscode/db_stats_client'
require 'opscode/mappers/base'
require 'opscode/mappers/user'
require 'opscode/mappers/client'
require 'opscode/mappers/opc_customer'
require 'opscode/mappers/container'

module Opscode
  module Mappers
    class Mappers
      # Instantiate all mappers 

      # Convenience class for initializing Mappers::Container objects:
      # * db::: Sequel database connection
      # * amqp::: Chef AMQP client
      # * org_id::: Organization GUID
      # * stats_client::: statsd client
      # * authz_id::: AuthZ id of the actor making the request
      MapperConfig = Struct.new(:sql, :couchdb, :amqp, :org_id, :stats_client, :authz_id)

      # Arguments are supplied by passing a
      # block, which yields a MapperConfig object. Example:
      #     Opscode::Mappers::Client.new do |m|
      #       m.db = Sequel.connect("mysql2:// ...")
      #       m.amqp = Chef::AmqpClient.instance
      #       m.org_id = "fffffff ..."
      #       m.stats_client = request.env['statsd.service.client'] # we use statsd via middleware
      #       m.authz_id = "123defffff ..."
      #     end
      # All attributes of the MapperConfig are required.

      attr_reader :authz_id
      attr_reader :client
      attr_reader :container
      attr_reader :opc_customer
      attr_reader :user

      def initialize
        conf = MapperConfig.new
        if block_given?
          yield conf
        end

        @user = Opscode::Mappers::User.new(conf.sql, conf.stats_client, conf.authz_id)

        if !conf.org_id.nil? 
          @client = Opscode::Mappers::Client.new do |m|
            m.db = conf.sql
            m.amqp = conf.amqp
            m.org_id = conf.org_id
            m.stats_client = conf.stats_client
            m.authz_id = conf.authz_id
          end          
          
          @container = Opscode::Mappers::Container.new do |m| 
            m.db = conf.sql
            m.org_id = conf.org_id
            m.stats_client = conf.stats_client
            m.authz_id = conf.authz_id
          end
        else
          @client = nil
          @container = nil
        end

        @authz_id = Mixlib::Authorization::AuthzIDMapper.new(conf.couchdb,
                                                             user,
                                                             client)

      end
    end
  end
end

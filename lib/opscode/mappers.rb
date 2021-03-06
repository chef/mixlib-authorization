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
require 'opscode/mappers/group'

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
      MapperConfig = Struct.new(:sql, :couchdb, :amqp, :org_id, :org_name, :stats_client, :authz_id, :containers_in_sql, :groups_in_sql )

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
      attr_reader :group
      attr_reader :opc_customer
      attr_reader :user
      attr_reader :containers_in_sql
      attr_reader :groups_in_sql

      def initialize
        conf = MapperConfig.new
        if block_given?
          yield conf
        end

        @containers_in_sql = conf.containers_in_sql
        @groups_in_sql = conf.groups_in_sql

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
          @group = Opscode::Mappers::Group.new do |m|
            m.db = conf.sql
            m.org_id = conf.org_id
            m.org_name = conf.org_name
            m.stats_client = conf.stats_client
            m.authz_id = conf.authz_id
          end
        else
          @client = nil
          @container = nil
          @group = nil
        end

        @authz_id = Mixlib::Authorization::AuthzIDMapper.new(conf.couchdb,
                                                             user,
                                                             client,
                                                             group,
                                                             conf.groups_in_sql)

        if !conf.org_id.nil?
          @group.authz_id_mapper = @authz_id
        end

      end
    end
  end
end

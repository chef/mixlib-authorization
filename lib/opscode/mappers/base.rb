require 'sequel'
require 'yajl'
require 'uuidtools'
require 'statsd/client'

# UTC4Life plz:
Sequel.default_timezone = :utc

module Opscode
  module Mappers
    module MapperStats

      attr_reader :total_db_calls
      attr_reader :total_db_time

      def setup_request
        @total_db_calls = 0
        @total_db_time = 0
      end

      def db_call
        begin
          increment("upstreamRequests.totalDatabaseCalls")
          @total_db_calls += 1
          start_time = Time.now
          yield
        rescue => e
          pp [e.class, e.message, e.backtrace]
        ensure
          end_time = Time.now
          elapsed_ms = ((end_time - start_time) * 1000).round
          timing("upstreamRequests.databaseCall", elapsed_ms)
          @total_db_time += elapsed_ms
        end
      end

    end
  end

end

Statsd::Client.send(:include, Opscode::Mappers::MapperStats)


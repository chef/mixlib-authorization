
module Opscode

  #== DBStatsTracking
  # A Mixin for Merb Controllers to measure the timing and count of database
  # requests.
  #
  #=== Provides:
  # Including this mixin does the following:
  # * defines a before filter that initializes a StatsdWrapper for the request.
  #   This object can be passed to the initializer of the mapper classes.
  # * defines an after filter that writes the aggregate stats from the statsd
  #   wrapper to estatsd.
  # * defines an attr_reader for db_stats to access the wrapped statsd client.
  #
  #=== Contract:
  # This mixin requires:
  # * The including class defines a class method +before+ and +after+ to define
  #   a before and after filter
  # * The including class defines an instance method +request+ and the Rack env
  #   hash can be accessed via +request.env+
  #
  # These requirements are met by anything that subclasses Merb::Controller
  module DBStatsTracking

    # Wraps a Statsd::Client Object, and provides an interface to measure the
    # timing of database operations.
    class StatsdWrapper

      attr_reader :total_db_calls
      attr_reader :total_db_time
      attr_reader :statsd_client

      def initialize(statsd_client)
        @total_db_calls = 0
        @total_db_time = 0
        @statsd_client = statsd_client
      end

      # Times the request and increments the total number of requests.
      # This is the method that the Opscode::Mapper objects will call.
      def db_call
        begin
          @statsd_client.increment("upstreamRequests.totalDatabaseCalls")
          @total_db_calls += 1
          start_time = Time.now
          yield
        ensure
          end_time = Time.now
          elapsed_ms = ((end_time - start_time) * 1000).round
          @statsd_client.timing("upstreamRequests.databaseCall", elapsed_ms)
          @total_db_time += elapsed_ms
        end
      end

      def write_request_summary
        @statsd_client.count("upstreamRequests.databaseCallsPerReq", @total_db_calls)
        @statsd_client.timing("upstreamRequests.databaseCalltimePerReq", @total_db_time)
      end

    end

    # Callback that fires when you include this module. Defines a before filter
    # for setup_db_stats_client and an after filter for write_db_stats
    def self.included(includer)
      includer.class_eval do
        before(:setup_db_stats_client)
        after(:write_db_stats)
      end
    end

    # Access to the StatsdWrapper instance for this request.
    attr_reader :db_stats

    # Setup the StatsdWrapper for this request.
    def setup_db_stats_client
      raw_statsd_client = request.env['statsd.service.client']
      @db_stats = StatsdWrapper.new(raw_statsd_client)
    end

    # Write the aggregate db stats for this request.
    def write_db_stats
      @db_stats.write_request_summary
      @db_stats = nil # prevent reuse
      true
    end


  end
end

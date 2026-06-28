module Stoplight
  module DataStore
    # @api private not for public use
    class Base
    end

    class Redis < Base
      # @!attribute redis
      #   @return [::Redis, ConnectionPool<::Redis>]
      attr_reader :redis

      # @!attribute warn_on_clock_skew
      #   @return [Boolean]
      attr_reader :warn_on_clock_skew

      # @param redis [::Redis, ConnectionPool<::Redis>]
      # @param warn_on_clock_skew [Boolean] (true) Whether to warn about clock skew between Redis and
      #   the application server
      def initialize(redis, warn_on_clock_skew: true)
        @warn_on_clock_skew = warn_on_clock_skew
        @redis = redis
      end
    end

    class Postgres < Base
      # @!attribute connection
      #   @return [::PG::Connection, ConnectionPool<::PG::Connection>]
      attr_reader :connection

      # @!attribute warn_on_clock_skew
      #   @return [Boolean]
      attr_reader :warn_on_clock_skew

      # @param connection [::PG::Connection, ConnectionPool<::PG::Connection>]
      # @param warn_on_clock_skew [Boolean] (true) accepted for interface parity with Redis;
      #   the Postgres adapter uses the database clock, so cross-node skew does not apply.
      def initialize(connection, warn_on_clock_skew: true)
        @warn_on_clock_skew = warn_on_clock_skew
        @connection = connection
      end
    end

    class Memory < Base
    end
  end
end

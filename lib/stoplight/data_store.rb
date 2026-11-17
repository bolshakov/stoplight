module Stoplight
  module DataStore
    # Builds the error raised wherever Stoplight has to choose behavior based on the configured
    # data store and receives one it does not know how to handle.
    #
    # @api private
    # @param data_store [Object] the unsupported data store
    # @return [TypeError]
    def self.unsupported(data_store)
      supported = [Redis, Memory].map(&:name).join(", ")
      TypeError.new("Unsupported data store: #{data_store.class}. Supported data stores: #{supported}")
    end

    # @api private not for public use
    class Base
    end

    class Redis < Base
      KEY_SPACE = Infrastructure::Redis::Key.new("stoplight", "v6")
      private_constant :KEY_SPACE

      # @!attribute redis
      #   @return [::Redis, ConnectionPool<::Redis>]
      attr_reader :redis

      # @param redis [::Redis, ConnectionPool<::Redis>]
      def initialize(redis)
        @redis = redis
      end

      # Immutable key namespace for a light within a system.
      #
      # Produces keys following entity-first structure:
      #   stoplight:{version}:{system_id}:{{light_id}}:locks:recovery
      #   stoplight:{version}:{system_id}:{{light_id}}:metrics:successes
      #   stoplight:{version}:{system_id}:{{light_id}}:state
      #
      # Identifiers are derived from SHA-256 and truncated to 12 characters. Collisions are extremely
      # unlikely at expected system scale.
      #
      # @see Stoplight::Infrastructure::Redis::Key
      def self.key_space = KEY_SPACE
      def key_space = self.class.key_space

      # Lua scripts are loaded into Redis once per server, so every light shares a single script cache.
      #
      # @api private
      def __stoplight__scripting
        @scripting ||= Infrastructure::Redis::Storage::Scripting.new(redis:)
      end
    end

    class Memory < Base
    end
  end
end

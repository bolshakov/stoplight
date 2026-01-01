# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      class DataStore
        # Manages Lua scripts for Redis operations.
        #
        # This class provides execution of Lua scripts by caching their SHA digests
        # and automatically reloading scripts if they're evicted from Redis memory.
        #
        # @example
        #   script_manager = ScriptManager.new(redis: redis_client)
        #   script_manager.call(:increment_counter, keys: ["counter:1"], args: [5])
        #
        # @note Scripts are loaded lazily on first use and cached in memory
        # @note Script files must be named `<script_name>.lua` and located in scripts_root
        class Scripting
          current_dir = __dir__ or raise "Cannot determine script directory"
          SCRIPTS_ROOT = File.join(current_dir, "lua_scripts")
          private_constant :SCRIPTS_ROOT

          class << self
            def default_scripts_root = SCRIPTS_ROOT
          end

          # @!attribute scripts_root
          #   @return [String]
          # @dynamic scripts_root
          protected attr_reader :scripts_root

          # @!attribute shas
          #   @return [Hash{Symbol, String}]
          # @dynamic shas
          private attr_reader :shas

          # @!attribute redis
          #   @return [RedisClient | ConnectionPool]
          # @dynamic redis
          protected attr_reader :redis

          # @param redis [RedisClient | ConnectionPool]
          # @param scripts_root [String]
          def initialize(redis:, scripts_root: self.class.default_scripts_root)
            @scripts_root = scripts_root
            @redis = redis
            @shas = {}
          end

          def call(script_name, keys: [], args: [])
            redis.then do |client|
              client.evalsha(script_sha(script_name), keys: keys.map(&:to_s), argv: args.map(&:to_s))
            end
          rescue ::Redis::CommandError => error
            if error.message.include?("NOSCRIPT")
              reload_script(script_name)
              retry
            else
              raise
            end
          end

          private def reload_script(script_name)
            shas.delete(script_name)
            script_sha(script_name)
          end

          private def script_sha(script_name)
            if shas.key?(script_name)
              shas[script_name]
            else
              script = File.read(File.join(scripts_root, "#{script_name}.lua"))

              shas[script_name] = redis.then { |client| client.script(:load, script) }
            end
          end
        end
      end
    end
  end
end

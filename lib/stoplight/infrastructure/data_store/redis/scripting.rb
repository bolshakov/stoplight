# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
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
          SCRIPTS_ROOT = File.join(__dir__, "lua_scripts")
          # @!attribute scripts_root
          #   @return [String]
          protected attr_reader :scripts_root

          # @!attribute shas
          #   @return [Hash{Symbol, String}]
          private attr_reader :shas

          # @!attribute redis
          #   @return [RedisClient | ConnectionPool]
          protected attr_reader :redis

          # @param redis [RedisClient | ConnectionPool]
          # @param scripts_root [String]
          def initialize(redis:, scripts_root: SCRIPTS_ROOT)
            @scripts_root = scripts_root
            @redis = redis
            @shas = {}
          end

          def call(script_name, keys: [], args: [])
            redis.then do |client|
              client.evalsha(script_sha(script_name), keys: keys, argv: args)
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

              shas[script_name] = redis.then { |client| client.script("load", script) }
            end
          end
        end
      end
    end
  end
end

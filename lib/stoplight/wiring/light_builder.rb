# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Wiring
    # Constructs a fully-wired Light instance from validated configuration.
    #
    # LightBuilder is the final assembly step in the Light creation pipeline.
    # It receives validated config and dependencies from ConfigurationPipeline
    # and wires together all infrastructure components (data stores, trackers,
    # strategies) needed for a functioning circuit breaker.
    #
    # LightBuilder maintains a global registry (MEMORY_REGISTRY) that ensures
    # the same Memory data store config object always produces the same
    # data store instance:
    #
    #   data_store = Stoplight::DataStore::Memory.new
    #   light1 = Stoplight("foo", data_store: data_store)
    #   light2 = Stoplight("bar", data_store: data_store)
    #   # light1 and light2 share the same underlying memory store
    #
    #   light3 = Stoplight("baz", data_store: Stoplight::DataStore::Memory.new)
    #   # light3 has its own independent store
    #
    # This singleton behavior is keyed by config object identity (object_id),
    # not by value equality.
    #
    # @api private
    class LightBuilder
      FAILOVER_DATA_STORE_CONFIG = Stoplight::DataStore::Memory.new
      private_constant :FAILOVER_DATA_STORE_CONFIG

      MEMORY_REGISTRY = Concurrent::Map.new
      private_constant :MEMORY_REGISTRY

      # @!attribute data_store_config
      #   @return [Stoplight::DataStore::Bose]
      private attr_reader :data_store_config

      # @!attribute error_notifier
      #   @return [Proc]
      private attr_reader :error_notifier

      # @!attribute traffic_recovery
      #   @return [Stoplight::Domain::TrafficRecovery::Base]
      private attr_reader :traffic_recovery

      # @!attribute traffic_control
      #   @return [Stoplight::Domain::TrafficControl::Base]
      private attr_reader :traffic_control

      # @!attribute config
      #   @return [Stoplight::Domain::Config]
      private attr_reader :config

      # @!attribute factory
      #   @return [Stoplight::Domain::LightFactory]
      private attr_reader :factory

      def initialize(settings)
        @notifiers = settings[:notifiers]
        @data_store_config = settings[:data_store]
        @error_notifier = settings[:error_notifier]
        @traffic_recovery = settings[:traffic_recovery]
        @traffic_control = settings[:traffic_control]
        @config = settings[:config]
        @factory = settings[:factory]
      end

      def build
        Stoplight::Domain::Light.new(
          config,
          data_store: data_store,
          green_run_strategy: green_run_strategy,
          yellow_run_strategy: yellow_run_strategy,
          red_run_strategy: red_run_strategy,
          factory: factory
        )
      end

      # @return [<Stoplight::Notifier::Base>]
      private def notifiers
        Array(@notifiers).map do |notifier|
          Infrastructure::Notifier::FailSafe.new(notifier:, error_notifier:)
        end
      end

      private def redis_recovery_lock_store
        Infrastructure::DataStore::Redis::RecoveryLockStore.new(
          redis: data_store_config.redis,
          lock_timeout: config.cool_off_time_in_milliseconds,
          scripting:
        )
      end

      private def scripting = Infrastructure::DataStore::Redis::Scripting.new(redis: data_store_config.redis)

      private def memory_recovery_lock_store
        Infrastructure::DataStore::Memory::RecoveryLockStore.new
      end

      private def failover_data_store
        create_data_store(FAILOVER_DATA_STORE_CONFIG)
      end

      private def data_store
        create_data_store(data_store_config)
      end

      private def request_tracker
        Domain::Tracker::Request.new(data_store:, traffic_control:, notifiers:, config:)
      end

      private def recovery_probe_tracker
        Domain::Tracker::RecoveryProbe.new(data_store:, traffic_recovery:, notifiers:, config:)
      end

      private def green_run_strategy
        Domain::Strategies::GreenRunStrategy.new(config:, request_tracker:)
      end

      private def yellow_run_strategy
        Domain::Strategies::YellowRunStrategy.new(
          config:,
          data_store:,
          notifiers:,
          request_tracker: recovery_probe_tracker,
          red_run_strategy:
        )
      end

      private def red_run_strategy
        Domain::Strategies::RedRunStrategy.new(config:)
      end

      private def create_data_store(data_store_config)
        case data_store_config
        in Stoplight::DataStore::Memory
          memory_registry.compute_if_absent(data_store_config.object_id) do
            Infrastructure::DataStore::Memory.new(
              recovery_lock_store: memory_recovery_lock_store
            )
          end
        in Stoplight::DataStore::Redis
          Infrastructure::DataStore::FailSafe.new(
            data_store: Stoplight::Infrastructure::DataStore::Redis.new(
              redis: data_store_config.redis,
              warn_on_clock_skew: data_store_config.warn_on_clock_skew,
              recovery_lock_store: redis_recovery_lock_store,
              scripting:
            ),
            error_notifier:,
            failover_data_store:,
            circuit_breaker: Stoplight.system_light("data_store:fail_safe:redis")
          )
        end
      end

      private def memory_registry = MEMORY_REGISTRY
    end
  end
end

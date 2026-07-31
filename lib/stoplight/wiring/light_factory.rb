# frozen_string_literal: true

module Stoplight
  module Wiring
    # Wires together all infrastructure components (trackers, strategies, storage
    # backend) needed for a functioning circuit breaker.
    #
    # @api private
    class LightFactory
      def initialize(system_id:, system_name:, config:, failover_system:, telemetry:)
        @system_id = system_id
        @system_name = system_name
        @failover_system = failover_system
        @config = config

        @clock = Infrastructure::SystemClock.new
        @name = T.must(config.name)
        @cool_off_time = config.cool_off_time

        @data_store_config = config.data_store
        @error_notifier = config.error_notifier
        @notifiers = config.notifiers
        @traffic_recovery = config.traffic_recovery
        @traffic_control = config.traffic_control

        @error_tracking_policy = Domain::ErrorTrackingPolicy.new(
          tracked: config.tracked_errors,
          skipped: config.skipped_errors
        )

        @emitter = Domain::Telemetry::Emitter.new(
          bus: telemetry,
          system_name: @system_name,
          light_name: config.name,
          clock: @clock,
          error_notifier: @error_notifier
        )
        @wrapped_notifiers = nil
      end

      def build
        Stoplight::Domain::Light.new(
          @name,
          state_store:,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          lock_control:,
          error_tracking_policy: @error_tracking_policy
        )
      end

      def state_store = storage_set.state_store
      def metrics_store = storage_set.metrics_store
      def lock_control = Domain::LockControl.new(state_store:, emitter: @emitter)

      private

      attr_reader :data_store_config
      attr_reader :error_notifier
      attr_reader :clock
      attr_reader :traffic_control
      attr_reader :traffic_recovery
      attr_reader :config
      attr_reader :system_name

      def recovery_lock_store = storage_set.recovery_lock_store
      def recovery_metrics_store = storage_set.recovery_metrics_store
      def storage_scripting = Infrastructure::Redis::Storage::Scripting.new(redis:)
      def failover_system = T.must(@failover_system)

      def key_space = @key_space ||= Infrastructure::Redis::Storage::KeySpace.new(
        system_id: @system_id,
        light_id: @config.id
      )

      def storage_set
        @storage_set ||= StorageSetBuilder.new(backend: build_backend, windowed: !config.window_size.nil?).build
      end

      # @return [<Stoplight::Notifier::Base>]
      def notifiers
        @wrapped_notifiers ||= Array(@notifiers).map do |notifier|
          Infrastructure::Notifier::FailSafe.new(
            notifier:,
            error_notifier:,
            circuit_breaker: create_circuit_breaker("notifier:#{notifier.class.name}")
          )
        end
      end

      def request_tracker
        Domain::Tracker::Request.new(traffic_control:, notifiers:, config:, metrics_store:, state_store:)
      end

      def recovery_probe_tracker
        Domain::Tracker::RecoveryProbe.new(
          traffic_recovery:,
          notifiers:,
          config:,
          metrics_store: recovery_metrics_store,
          state_store:,
          emitter: @emitter
        )
      end

      def green_run_strategy
        Domain::Strategies::GreenRunStrategy.new(
          request_tracker:,
          clock:,
          run_recorder: run_recorder(Color::GREEN)
        )
      end

      def yellow_run_strategy
        Domain::Strategies::YellowRunStrategy.new(
          name: @name,
          notifiers:,
          request_tracker: recovery_probe_tracker,
          state_store:,
          metrics_store:,
          recovery_lock_store:,
          config: @config,
          clock:,
          run_recorder: run_recorder(Color::YELLOW)
        )
      end

      def red_run_strategy
        Domain::Strategies::RedRunStrategy.new(
          name: @name,
          cool_off_time: @cool_off_time,
          run_recorder: run_recorder(Color::RED)
        )
      end

      def run_recorder(color)
        Domain::Telemetry::RunRecorder.new(emitter: @emitter, color:)
      end

      def redis
        case data_store_config
        when DataStore::Redis
          data_store_config.redis
        else
          raise TypeError, "Expected Stoplight::DataStore::Redis, got #{data_store_config}"
        end
      end

      def build_backend
        case data_store_config
        in DataStore::Memory
          Memory::Backend.new(clock:, config:)
        in DataStore::Redis
          Redis::Backend.new(
            redis:, scripting: storage_scripting, key_space:, clock:, config:, error_notifier:,
            failover_light: create_circuit_breaker("redis")
          )
        end
      end

      def create_circuit_breaker(name)
        failover_system.register(name)
      end
    end
  end
end

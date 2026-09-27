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
        @error_notifier = Infrastructure::FailSafe::ErrorNotifier.new(
          error_notifier: config.error_notifier
        )
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
      end

      def build
        light = Stoplight::Domain::Light.new(
          @name,
          state_store:,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          lock_control:,
          error_tracking_policy: @error_tracking_policy
        )

        @emitter.emit(Domain::Telemetry::LightRegistered) do
          Domain::Telemetry::LightRegistered.new(settings: telemetry_settings)
        end

        light
      end

      def state_store = storage_set.state_store
      def metrics_store = storage_set.metrics_store
      def lock_control = Domain::LockControl.new(state_store:, emitter: @emitter)
      def recovery_metrics_store = storage_set.recovery_metrics_store

      private

      attr_reader :data_store_config
      attr_reader :error_notifier
      attr_reader :clock
      attr_reader :traffic_control
      attr_reader :traffic_recovery
      attr_reader :config
      attr_reader :system_name

      def recovery_lock_store = storage_set.recovery_lock_store
      def storage_scripting = Infrastructure::Redis::Storage::Scripting.new(redis:)
      def failover_system = T.must(@failover_system)

      def key_space
        @key_space ||= case data_store_config
        when DataStore::Redis
          # We use keys like +stoplight:version:system_id:{light_id}:metrics+ prefixes,
          # Putting +liht_id+ into curly braces make it a Redis Cluster hash-tag - this is a  segment
          # for slot colocation.
          data_store_config.key_space.join(@system_id, "{#{@config.id}}")
        else
          raise T.absurd(data_store_config)
        end
      end

      def storage_set
        @storage_set ||= StorageSetBuilder.new(backend: build_backend, windowed: !config.window_size.nil?).build
      end

      def request_tracker
        Domain::Tracker::Request.new(traffic_control:, config:, metrics_store:, state_store:, emitter: @emitter)
      end

      def recovery_probe_tracker
        Domain::Tracker::RecoveryProbe.new(
          traffic_recovery:,
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
          request_tracker: recovery_probe_tracker,
          state_store:,
          metrics_store:,
          recovery_lock_store:,
          config: @config,
          clock:,
          run_recorder: run_recorder(Color::YELLOW),
          emitter: @emitter
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

      def telemetry_settings
        Domain::Telemetry::Settings.new(
          cool_off_time: @config.cool_off_time,
          threshold: @config.threshold,
          recovery_threshold: @config.recovery_threshold,
          window_size: @config.window_size,
          tracked_errors: @config.tracked_errors.map { |matcher| Domain::MatcherValidator.call(matcher) },
          skipped_errors: @config.skipped_errors.map { |matcher| Domain::MatcherValidator.call(matcher) },
          traffic_control: @config.traffic_control.name,
          traffic_recovery: @config.traffic_recovery.name,
          # No strategy accepts constructor params yet; placeholder for forward compatibility.
          traffic_control_params: {},
          traffic_recovery_params: {}
        )
      end

      def redis
        case data_store_config
        when DataStore::Redis
          data_store_config.redis
        else
          raise T.absurd(data_store_config)
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

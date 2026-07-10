# frozen_string_literal: true

module Stoplight
  module Wiring
    # Constructs a fully-wired Light instance from validated configuration.
    #
    # Wires together all infrastructure components (trackers, strategies) needed
    # for a functioning circuit breaker. Subclasses supply the storage backend
    # (state, metrics, recovery-lock stores).
    #
    # @api private
    class LightFactory
      def initialize(config:)
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

        @wrapped_notifiers = nil
      end

      def build
        Stoplight::Domain::Light.new(
          @name,
          state_store:,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:
        )
      end

      private

      attr_reader :data_store_config
      attr_reader :error_notifier
      attr_reader :clock
      attr_reader :traffic_control
      attr_reader :traffic_recovery
      attr_reader :config

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
          state_store:
        )
      end

      def green_run_strategy
        Domain::Strategies::GreenRunStrategy.new(
          error_tracking_policy: @error_tracking_policy,
          request_tracker:
        )
      end

      def yellow_run_strategy
        Domain::Strategies::YellowRunStrategy.new(
          name: @name,
          error_tracking_policy: @error_tracking_policy,
          notifiers:,
          request_tracker: recovery_probe_tracker,
          red_run_strategy:,
          state_store:,
          metrics_store:,
          recovery_lock_store:,
          config: @config
        )
      end

      def red_run_strategy
        Domain::Strategies::RedRunStrategy.new(name: @name, cool_off_time: @cool_off_time)
      end

      def redis
        case data_store_config
        when DataStore::Redis
          data_store_config.redis
        else
          raise TypeError, "Expected Stoplight::DataStore::Redis, got #{data_store_config.class}"
        end
      end
    end
  end
end

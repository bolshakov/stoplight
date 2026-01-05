# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightFactory
      # Orchestrates DSL interpretation, normalization, and validation.
      #
      # ConfigurationPipeline is the entry point for transforming raw user settings
      # into validated domain objects. It coordinates three steps:
      #
      # 1. Normalization - Convert user-friendly values to canonical forms
      # 2. DSL Interpretation - Transform symbols/hashes into strategy objects
      # 3. Validation - Ensure strategies are compatible with configuration
      #
      # @api private
      class ConfigurationPipeline
        private attr_reader :settings

        def self.process(settings:)
          new(settings:).process
        end

        def initialize(settings:)
          @settings = settings
        end

        def process
          config = build_config

          CompatibilityValidator.call(config:)

          config
        end

        def build_config
          Domain::Config.new(
            name:,
            cool_off_time:,
            threshold:,
            recovery_threshold:,
            window_size:,
            skipped_errors:,
            tracked_errors:,
            traffic_control:,
            traffic_recovery:,
            error_notifier:,
            notifiers:,
            data_store:
          )
        end

        private def name = settings.name.get_or_else { raise ArgumentError, "name is required" }

        private def cool_off_time = settings.cool_off_time.get_or_else { Default::COOL_OFF_TIME }

        private def threshold = settings.threshold.get_or_else { Default::THRESHOLD }

        private def recovery_threshold = settings.recovery_threshold.get_or_else { Default::RECOVERY_THRESHOLD }

        private def window_size = settings.window_size.get_or_else { Default::WINDOW_SIZE }

        private def skipped_errors
          settings.skipped_errors
            .map { Array(_1) }
            .get_or_else { Default::SKIPPED_ERRORS }
        end

        private def tracked_errors
          settings.tracked_errors
            .map { Array(_1) }
            .get_or_else { Default::TRACKED_ERRORS }
        end

        private def traffic_control
          settings.traffic_control
            .map { TrafficControlDsl.call(_1) }
            .get_or_else { Default::TRAFFIC_CONTROL }
        end

        private def traffic_recovery
          settings.traffic_recovery
            .map { TrafficRecoveryDsl.call(_1) }
            .get_or_else { Default::TRAFFIC_RECOVERY }
        end

        private def error_notifier = settings.error_notifier.get_or_else { Default::ERROR_NOTIFIER }

        private def notifiers = settings.notifiers.get_or_else { Default::NOTIFIERS }

        private def data_store = settings.data_store.get_or_else { Default::DATA_STORE }
      end
    end
  end
end

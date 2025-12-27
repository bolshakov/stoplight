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
        private attr_reader :dependency_settings
        private attr_reader :config_settings

        def self.process(config_settings, dependency_settings)
          new(config_settings, dependency_settings).process
        end

        def initialize(config_settings, dependency_settings)
          @config_settings = config_settings
          @dependency_settings = dependency_settings
        end

        def process
          config = build_config
          dependencies = build_dependencies

          CompatibilityValidator.call(config, dependencies)

          [config, dependencies]
        end

        def build_config
          base_config
            .with(**config_settings)
            .then { |cfg| ConfigNormalizer.call(cfg) }
        end

        def build_dependencies
          traffic_recovery = dependency_settings.fetch(:traffic_recovery, Default::TRAFFIC_RECOVERY)
          traffic_control = dependency_settings.fetch(:traffic_control, Default::TRAFFIC_CONTROL)
          {
            error_notifier: dependency_settings.fetch(:error_notifier, Default::ERROR_NOTIFIER),
            notifiers: dependency_settings.fetch(:notifiers, Default::NOTIFIERS),
            data_store: dependency_settings.fetch(:data_store, Default::DATA_STORE),
            traffic_control: TrafficControlDsl.call(traffic_control),
            traffic_recovery: TrafficRecoveryDsl.call(traffic_recovery)
          }
        end

        def base_config = Light::DefaultConfig
      end
    end
  end
end

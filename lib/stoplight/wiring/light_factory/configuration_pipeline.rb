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
        BASE_DEPENDENCIES = {
          data_store: Default::DATA_STORE,
          traffic_recovery: Default::TRAFFIC_RECOVERY,
          traffic_control: Default::TRAFFIC_CONTROL,
          notifiers: Default::NOTIFIERS,
          error_notifier: Default::ERROR_NOTIFIER
        }.freeze
        private_constant :BASE_DEPENDENCIES

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
          base_dependencies
            .merge(dependency_settings)
            .then { |deps| interpret_dsl(deps) }
        end

        def interpret_dsl(dependencies)
          dependencies.merge(
            traffic_control: TrafficControlDsl.call(dependencies.fetch(:traffic_control)),
            traffic_recovery: TrafficRecoveryDsl.call(dependencies.fetch(:traffic_recovery))
          )
        end

        def base_config = Light::DefaultConfig

        def base_dependencies = BASE_DEPENDENCIES
      end
    end
  end
end

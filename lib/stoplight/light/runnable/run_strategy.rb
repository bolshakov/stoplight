# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable
      # Represents a strategy for running a light's operations.
      #
      # @api private
      # @abstract
      class RunStrategy
        # @!attribute [r] config
        #   @return [Stoplight::Light::Config] The configuration for the light.
        private attr_reader :config

        # @!attribute [r] data_store
        #   @return [Stoplight::DataStore::Base] The data store associated with the light.
        private attr_reader :data_store

        # @param config [Stoplight::Light::Config] The configuration for the light.
        def initialize(config)
          @config = config
          @data_store = config.data_store
        end

        # Sends a notification about a light state change with deduplication.
        #
        # @param config [Stoplight::Light::Config] The configuration for the light.
        # @param from_color [String] The initial color of the light.
        # @param to_color [String] The target color of the light.
        # @param error [Exception, nil] An optional error to include in the notification.
        # @yield Executes the notification logic for each notifier.
        # @return [void]
        private def notify(config, from_color, to_color, error = nil)
          data_store.with_deduplicated_notification(config, from_color, to_color) do
            config.notifiers.each do |notifier|
              notifier.notify(config, from_color, to_color, error)
            end
          end
        end
      end
    end
  end
end

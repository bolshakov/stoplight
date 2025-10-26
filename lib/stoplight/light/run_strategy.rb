# frozen_string_literal: true

module Stoplight
  class Light
    # Represents an abstract strategy for running a light's operations.
    # Every new strategy should be a child of this class.
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

      # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
      # @param metadata [Stoplight::Metadata] Metadata capturing the current state of the light.
      # :nocov:
      def execute(fallback, metadata:, &code)
        raise NotImplementedError, "Subclasses must implement the execute method"
      end
      # :nocov:
    end
  end
end

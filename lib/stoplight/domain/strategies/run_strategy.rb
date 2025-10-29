# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Represents an abstract strategy for running a light's operations.
      # Every new strategy should be a child of this class.
      #
      # @api private
      # @abstract
      class RunStrategy
        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        protected attr_reader :config

        # @!attribute [r] data_store
        #   @return [Stoplight::DataStore::Base] The data store associated with the light.
        protected attr_reader :data_store

        # @param config [Stoplight::Domain::Config] The configuration for the light.
        # @param data_store [Stoplight::Domain::DataStore] The data store associated with the light.
        def initialize(config:, data_store:)
          @config = config
          @data_store = data_store
        end

        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param metadata [Stoplight::Domain::Metadata] Metadata capturing the current state of the light.
        # :nocov:
        def execute(fallback, metadata:, &code)
          raise NotImplementedError, "Subclasses must implement the execute method"
        end
        # :nocov:

        # @return [Boolean]
        def ==(other)
          other.is_a?(self.class) && config == other.config && data_store == other.data_store
        end
      end
    end
  end
end

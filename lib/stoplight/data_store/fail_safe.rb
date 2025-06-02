# frozen_string_literal: true

module Stoplight
  module DataStore
    # A wrapper around a data store that provides fail-safe mechanisms using a
    # circuit breaker. It ensures that operations on the data store can gracefully
    # handle failures by falling back to default values when necessary.
    #
    # @api private
    class FailSafe < Base
      # @!attribute [r] data_store
      #   @return [Stoplight::DataStore::Base] The underlying data store being wrapped.
      protected attr_reader :data_store

      # @!attribute [r] circuit_breaker
      #   @return [Stoplight] The circuit breaker used to handle failures.
      private attr_reader :circuit_breaker

      class << self
        # Wraps a data store with fail-safe mechanisms.
        #
        # @param data_store [Stoplight::DataStore::Base] The data store to wrap.
        # @return [Stoplight::DataStore::Base, FailSafe] The original data store if it is already
        #   a +Memory+ or +FailSafe+ instance, otherwise a new +FailSafe+ instance.
        def wrap(data_store)
          case data_store
          when Memory, FailSafe
            data_store
          else
            new(data_store)
          end
        end
      end

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store)
        @data_store = data_store
        @circuit_breaker = Stoplight("stoplight:data_store:fail_safe:#{data_store.class.name}", data_store: Default::DATA_STORE)
      end

      def names
        with_fallback([]) do
          data_store.names
        end
      end

      def get_metadata(config)
        with_fallback(Metadata.new, config) do
          data_store.get_metadata(config)
        end
      end

      def record_failure(config, failure)
        with_fallback(nil, config) do
          data_store.record_failure(config, failure)
        end
      end

      def record_success(config, **args)
        with_fallback(nil, config) do
          data_store.record_success(config, **args)
        end
      end

      def record_recovery_probe_success(config, **args)
        with_fallback(nil, config) do
          data_store.record_recovery_probe_success(config, **args)
        end
      end

      def record_recovery_probe_failure(config, failure)
        with_fallback(nil, config) do
          data_store.record_recovery_probe_failure(config, failure)
        end
      end

      def set_state(config, state)
        with_fallback(State::UNLOCKED, config) do
          data_store.set_state(config, state)
        end
      end

      def transition_to_color(config, color)
        with_fallback(false, config) do
          data_store.transition_to_color(config, color)
        end
      end

      def ==(other)
        other.is_a?(self.class) && other.data_store == data_store
      end

      # @param default [Object, nil]
      # @param config [Stoplight::Light::Config]
      private def with_fallback(default = nil, config = nil, &code)
        fallback = proc do |error|
          config.error_notifier.call(error) if config && error
          default
        end

        circuit_breaker.run(fallback, &code)
      end
    end
  end
end

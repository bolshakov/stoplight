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
      end

      def names
        with_fallback([]) do
          data_store.names
        end
      end

      def get_all(config)
        with_fallback([[], State::UNLOCKED], config) do
          data_store.get_all(config)
        end
      end

      def get_state(config)
        with_fallback(State::UNLOCKED, config) do
          data_store.get_state(config)
        end
      end

      def get_failures(config)
        with_fallback([], config) do
          data_store.get_failures(config)
        end
      end

      def record_failure(config, failure)
        with_fallback(0, config) do
          data_store.record_failure(config, failure)
        end
      end

      def clear_failures(config)
        with_fallback([], config) do
          data_store.clear_failures(config)
        end
      end

      def set_state(config, state)
        with_fallback(State::UNLOCKED, config) do
          data_store.set_state(config, state)
        end
      end

      def clear_state(config)
        with_fallback(State::UNLOCKED, config) do
          data_store.clear_state(config)
        end
      end

      def with_deduplicated_notification(config, from_color, to_color, &notification)
        with_fallback(nil, config) do
          data_store.with_deduplicated_notification(config, from_color, to_color, &notification)
        end
      end

      def ==(other)
        other.is_a?(self.class) && other.data_store == data_store
      end

      # @param default [Object, nil]
      # @param config [Stoplight::Light::Config]
      private def with_fallback(default = nil, config = nil, &code)
        yield
      rescue => error
        config.error_notifier.call(error) if config && error
        default
      end
    end
  end
end

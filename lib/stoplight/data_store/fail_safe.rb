# frozen_string_literal: true

require "securerandom"

module Stoplight
  module DataStore
    # A wrapper around a data store that provides fail-safe mechanisms using a
    # circuit breaker. It ensures that operations on the data store can gracefully
    # handle failures by falling back to default values when necessary.
    #
    # @api private
    class FailSafe < Base
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

      # @!attribute data_store
      #  @return [Stoplight::DataStore::Base] The underlying primary data store being used
      protected attr_reader :data_store

      # @!attribute failover_data_store
      #   @return [Stoplight::DataStore::Base] The fallback data store used when the primary fails.
      private attr_reader :failover_data_store

      # @!attribute circuit_breaker
      #   @return [Stoplight::Light] The circuit breaker used to handle data store failures.
      private attr_reader :circuit_breaker

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store, failover_data_store: Default::DATA_STORE)
        @data_store = data_store
        @failover_data_store = failover_data_store
        @circuit_breaker = Stoplight.system_light("stoplight:data_store:fail_safe:#{data_store.class.name}")
      end

      def names
        with_fallback(:names) do
          data_store.names
        end
      end

      def get_metadata(config, *args, **kwargs)
        with_fallback(:get_metadata, config, *args, **kwargs) do
          data_store.get_metadata(config, *args, **kwargs)
        end
      end

      def record_failure(config, *args, **kwargs)
        with_fallback(:record_failure, config, *args, **kwargs) do
          data_store.record_failure(config, *args, **kwargs)
        end
      end

      def record_success(config, *args, **kwargs)
        with_fallback(:record_success, config, *args, **kwargs) do
          data_store.record_success(config, *args, **kwargs)
        end
      end

      def record_recovery_probe_success(config, *args, **kwargs)
        with_fallback(:record_recovery_probe_success, config, *args, **kwargs) do
          data_store.record_recovery_probe_success(config, *args, **kwargs)
        end
      end

      def record_recovery_probe_failure(config, *args, **kwargs)
        with_fallback(:record_recovery_probe_failure, config, *args, **kwargs) do
          data_store.record_recovery_probe_failure(config, *args, **kwargs)
        end
      end

      def set_state(config, *args, **kwargs)
        with_fallback(:set_state, config, *args, **kwargs) do
          data_store.set_state(config, *args, **kwargs)
        end
      end

      def transition_to_color(config, *args, **kwargs)
        with_fallback(:transition_to_color, config, *args, **kwargs) do
          data_store.transition_to_color(config, *args, **kwargs)
        end
      end

      def ==(other)
        other.is_a?(self.class) && other.data_store == data_store
      end

      # @param method_name [Symbol] protected method name
      private def with_fallback(method_name, *args, **kwargs, &code)
        fallback = proc do |error|
          config = args.first
          config.error_notifier.call(error) if config && error
          @failover_data_store.public_send(method_name, *args, **kwargs)
        end

        circuit_breaker.run(fallback, &code)
      end
    end
  end
end

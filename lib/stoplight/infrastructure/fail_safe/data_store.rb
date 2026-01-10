# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module FailSafe
      # A wrapper around a data store that provides fail-safe mechanisms using a
      # circuit breaker. It ensures that operations on the data store can gracefully
      # handle failures by falling back to default values when necessary.
      #
      # @api private
      # steep:ignore:start
      class DataStore
        # The underlying primary data store being used
        attr_reader :data_store
        attr_reader :error_notifier
        # The fallback data store used when the primary fails.
        attr_reader :failover_data_store
        # The circuit breaker used to handle data store failures.
        private attr_reader :circuit_breaker

        def initialize(data_store:, error_notifier:, failover_data_store:, circuit_breaker:)
          @data_store = data_store
          @error_notifier = error_notifier
          @failover_data_store = failover_data_store
          @circuit_breaker = circuit_breaker
        end

        def names
          with_fallback(:names) do
            data_store.names
          end
        end

        def get_metrics(config, *args, **kwargs)
          with_fallback(:get_metrics, config, *args, **kwargs) do
            data_store.get_metrics(config, *args, **kwargs)
          end
        end

        def get_recovery_metrics(config, *args, **kwargs)
          with_fallback(:get_recovery_metrics, config, *args, **kwargs) do
            data_store.get_recovery_metrics(config, *args, **kwargs)
          end
        end

        def get_state_snapshot(config)
          with_fallback(:get_state_snapshot, config) do
            data_store.get_state_snapshot(config)
          end
        end

        def clear_metrics(config)
          with_fallback(:clear_metrics, config) do
            data_store.clear_metrics(config)
          end
        end

        def clear_recovery_metrics(config)
          with_fallback(:clear_recovery_metrics, config) do
            data_store.clear_recovery_metrics(config)
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

        def delete_light(config, *args, **kwargs)
          with_fallback(:delete_light, config, *args, **kwargs) do
            data_store.delete_light(config, *args, **kwargs)
          end
        end

        # @param config [Stoplight::Domain::Config]
        def acquire_recovery_lock(config)
          with_fallback(:acquire_recovery_lock, config) do
            data_store.acquire_recovery_lock(config)
          end
        end

        # Routes release to correct store based on token type.
        # Redis tokens release via primary (with error notification on failure).
        # Memory tokens release via failover directly.
        #
        def release_recovery_lock(recovery_lock_token)
          case recovery_lock_token
          in Redis::DataStore::RecoveryLockToken
            fallback = proc do |error|
              error_notifier.call(error) if error
            end

            circuit_breaker.run(fallback) do
              data_store.release_recovery_lock(recovery_lock_token)
            end
          in Memory::DataStore::RecoveryLockToken
            failover_data_store.release_recovery_lock(recovery_lock_token)
          end
        end

        def ==(other)
          other.is_a?(self.class) && other.data_store == data_store && other.error_notifier == error_notifier &&
            other.failover_data_store == failover_data_store
        end

        private def with_fallback(method_name, *args, **kwargs, &code)
          fallback = ->(error) {
            config = args.first
            error_notifier.call(error) if config && error
            failover_data_store.public_send(method_name, *args, **kwargs)
          }

          circuit_breaker.run(fallback, &code)
        end
      end
      # steep:ignore:end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Wiring
    class DataStoreFactory
      class << self
        # @param data_store [Stoplight::Domain::DataStore]
        # @param error_notifier [Stoplight::Domain::StateTransitionNotifier]
        # @param failover_data_store [Stoplight::Domain::DataStore]
        # @return [Stoplight::Infrastructure::FailSafe]
        def create(data_store:, error_notifier:, failover_data_store:)
          case data_store
          in Infrastructure::DataStore::Memory
            data_store
          in Infrastructure::DataStore::FailSafe if data_store.error_notifier == error_notifier && data_store.failover_data_store == failover_data_store
            data_store
          in Infrastructure::DataStore::FailSafe
            Infrastructure::DataStore::FailSafe.new(
              data_store: data_store.data_store,
              error_notifier:,
              failover_data_store:,
              circuit_breaker: Stoplight.system_light("data_store:fail_safe:#{data_store.data_store.class.name}")
            )
          else
            Infrastructure::DataStore::FailSafe.new(
              data_store: data_store,
              error_notifier:,
              failover_data_store:,
              circuit_breaker: Stoplight.system_light("data_store:fail_safe:#{data_store.class.name}")
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Wiring
    # This container implements an instance of +Stoplight::Infrastructure::DependencyInjection::Container+
    # with Stoplight-specific wiring knowledge. It defines how to construct and connect
    # all the components needed for a circuit breaker to function.
    #
    # ## Default Configuration
    #
    # The container is pre-configured with sensible defaults:
    # - Data Store - in-memory storage
    # - STDERR notifier
    # - No-op error notifier
    # - Consecutive failure detection
    # - Consecutive success recovery
    #
    # @see Infrastructure::DependencyInjection::Container Generic DI container
    # @see Stoplight::Wiring::LightFactory Factory that uses this container
    # @api private
    Container = Infrastructure::DependencyInjection::Container.define do
      register(:config, Light::DefaultConfig)
      register(:error_notifier, Default::ERROR_NOTIFIER)
      register(:traffic_control, Default::TRAFFIC_CONTROL)
      register(:traffic_recovery, Default::TRAFFIC_RECOVERY)

      # Wraps a data store with fail-safe mechanisms.
      #
      # @param data_store [Stoplight::DataStore::Base] The data store to wrap.
      # @param error_notifier [Proc] called when wrapped data store fails
      # @return [Stoplight::DataStore::Base, FailSafe] The original data store if it is already
      #   a +Memory+ or +FailSafe+ instance, otherwise a new +FailSafe+ instance.
      register(:data_store, Default::DATA_STORE) do |data_store|
        DataStoreFactory.create(
          data_store: data_store,
          error_notifier: resolve(:error_notifier),
          failover_data_store: Wiring::Default::DATA_STORE
        )
      end

      register(:notifiers, Default::NOTIFIERS) do |notifiers|
        error_notifier = resolve(:error_notifier)
        notifiers.map { |notifier| NotifierFactory.create(notifier:, error_notifier:) }
      end

      factory(:green_run_strategy) do
        Domain::Strategies::GreenRunStrategy.new(
          config: resolve(:config),
          request_tracker: resolve(:request_tracker)
        )
      end

      factory(:yellow_run_strategy) do
        Domain::Strategies::YellowRunStrategy.new(
          config: resolve(:config),
          data_store: resolve(:data_store),
          notifiers: resolve(:notifiers),
          request_tracker: resolve(:recovery_probe_tracker)
        )
      end

      factory(:red_run_strategy) do
        Domain::Strategies::RedRunStrategy.new(
          config: resolve(:config)
        )
      end

      factory(:request_tracker) do
        Domain::Tracker::Request.new(
          data_store: resolve(:data_store),
          traffic_control: resolve(:traffic_control),
          notifiers: resolve(:notifiers),
          config: resolve(:config)
        )
      end

      factory(:recovery_probe_tracker) do
        Domain::Tracker::RecoveryProbe.new(
          data_store: resolve(:data_store),
          traffic_recovery: resolve(:traffic_recovery),
          notifiers: resolve(:notifiers),
          config: resolve(:config)
        )
      end
    end
  end
end

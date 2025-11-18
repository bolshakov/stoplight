# frozen_string_literal: true

module Stoplight
  class Admin
    module Helpers
      COLORS = [
        GREEN = Stoplight::Color::GREEN,
        YELLOW = Stoplight::Color::YELLOW,
        RED = Stoplight::Color::RED
      ].freeze

      # @return [Stoplight::Admin::Dependencies]
      def dependencies
        Dependencies.new(data_store:)
      end

      private def data_store
        if settings.data_store.is_a?(Stoplight::DataStore::Memory)
          raise "Stoplight Admin requires a persistent data store, but the current data store is Memory. " \
            "Please configure a different data store in your Stoplight configuration."
        else
          Wiring::Container
            .with(data_store_config: settings.data_store, config: Wiring::Light::DefaultConfig)
            .resolve(:data_store)
        end
      end
    end
  end
end

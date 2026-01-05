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
          Stoplight::Wiring::LightBuilder.new(
            config: Wiring::Light::DefaultConfig.with(
              data_store: settings.data_store
            ),
            factory: nil
          ).__send__(:data_store)
        end
      end
    end
  end
end

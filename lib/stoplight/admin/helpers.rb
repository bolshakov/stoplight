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

      def asset_path(name)
        url("/#{name}?v=#{ASSET_DIGESTS.fetch(name)}")
      end

      def time_ago_in_words(time)
        time_difference = Time.now.utc - time
        if time_difference < 1
          "just now"
        elsif time_difference < 60
          "#{time_difference.to_i}s ago"
        elsif time_difference < 3600
          "#{(time_difference / 60).to_i}m ago"
        elsif time_difference < 86400
          "#{(time_difference / 3600).to_i}h ago"
        else
          "#{(time_difference / 86400).to_i}d ago"
        end
      end

      private def data_store
        if settings.data_store.is_a?(Stoplight::DataStore::Memory)
          raise "Stoplight Admin requires a persistent data store, but the current data store is Memory. " \
            "Please configure a different data store in your Stoplight configuration."
        else
          Stoplight::Wiring::LightFactory.new(
            config: Wiring::DefaultConfig.with(
              name: "noname",
              data_store: settings.data_store
            )
          ).__send__(:data_store)
        end
      end
    end
  end
end

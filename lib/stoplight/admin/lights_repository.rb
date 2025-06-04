# frozen_string_literal: true

module Stoplight
  class Admin
    class LightsRepository
      # @!attribute data_store
      #   @return [Stoplight::DataStore::Base]
      attr_reader :data_store
      private :data_store

      #  @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store:)
        @data_store = data_store
      end

      # @return [<Stoplight::Admin::LightsRepository::Light>]
      def all
        data_store
          .names
          .map { |name| load_light(name) }
          .sort_by(&:default_sort_key)
      end

      # @param colors <String>] colors name
      # @return [<Stoplight::Admin::LightsRepository::Light>] lights with the requested colors
      #
      def with_color(*colors)
        requested_colors = Array(colors)

        all.select do |light|
          requested_colors.include?(light.color)
        end
      end

      # @param name [String] locks light by its name
      # @param color [String, nil] locks to this color. When nil is given, locks to the current
      #   color
      # @return [void]
      def lock(name, color = nil)
        light = build_light(name)

        case color || light.color
        when Stoplight::Color::GREEN
          light.lock(Stoplight::Color::GREEN)
        else
          light.lock(Stoplight::Color::RED)
        end
      end

      # @param name [String] unlocks light by its name
      # @return [void]
      def unlock(name)
        build_light(name).unlock
      end

      private def load_light(name)
        light = build_light(name)
        # failures, state
        metadata = data_store.get_metadata(light.config)

        Light.new(
          name: name,
          color: light.color,
          state: metadata.locked_state,
          failures: [metadata.last_failure]
        )
      end

      private def build_light(name)
        Stoplight(name, data_store: data_store)
      end
    end
  end
end

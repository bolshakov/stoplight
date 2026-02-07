# frozen_string_literal: true

module Stoplight
  class Admin
    class LightsRepository
      # @!attribute data_store
      #   @return [Stoplight::Domain::_DataStore]
      attr_reader :data_store
      private :data_store

      #  @param data_store [Stoplight::Domain::_DataStore]
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
        config = build_config(name)
        color ||= data_store.get_state_snapshot(config).color

        case color
        when Stoplight::Color::GREEN
          data_store.set_state(config, Stoplight::State::LOCKED_GREEN)
        else
          data_store.set_state(config, Stoplight::State::LOCKED_RED)
        end
      end

      # @param name [String] unlocks light by its name
      # @return [void]
      def unlock(name)
        config = build_config(name)
        data_store.set_state(config, State::UNLOCKED)
      end

      # @param name [String] removes light metadata by its name
      # @return [void]
      def remove(name)
        config = build_config(name)

        data_store.delete_light(config)
      end

      private def load_light(name)
        config = build_config(name)

        # failures, state
        state_snapshot = data_store.get_state_snapshot(config)
        metrics = data_store.get_metrics(config)

        Light.new(
          name: name,
          color: state_snapshot.color,
          state: state_snapshot.locked_state,
          failures: [metrics.last_error].compact,
          failure_count: metrics.consecutive_errors
        )
      end

      private def build_config(name)
        Wiring::DefaultConfig.with(name:)
      end
    end
  end
end

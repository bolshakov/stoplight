# frozen_string_literal: true

require 'monitor'

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin
      KEY_SEPARATOR = ':'

      def initialize
        @failures = Hash.new { |h, k| h[k] = [] }
        @states = Hash.new { |h, k| h[k] = State::UNLOCKED }
        @last_notifications = {}
        super() # MonitorMixin
      end

      def names
        synchronize { @failures.keys | @states.keys }
      end

      def get_all(light)
        synchronize { [query_failures(light), @states[light.name]] }
      end

      def get_failures(light)
        synchronize { query_failures(light) }
      end

      def record_failure(light, failure)
        synchronize do
          light_name = light.name

          # Keep at most +light.threshold+ number of errors
          @failures[light_name] = @failures[light_name].first(light.threshold - 1)
          @failures[light_name].unshift(failure)
          # Remove all errors happened before the window start
          @failures[light_name] = query_failures(light, failure.time)
          @failures[light_name].size
        end
      end

      def clear_failures(light)
        synchronize { @failures.delete(light.name) }
      end

      def get_state(light)
        synchronize { @states[light.name] }
      end

      def set_state(light, state)
        synchronize { @states[light.name] = state }
      end

      def clear_state(light)
        synchronize { @states.delete(light.name) }
      end

      def with_notification_lock(light, from_color, to_color)
        synchronize do
          if last_notification(light) != [from_color, to_color]
            set_last_notification(light, from_color, to_color)

            yield
          end
        end
      end

      private

      # @param light [Stoplight::Light]
      # @return [Array, nil]
      def last_notification(light)
        @last_notifications[light.name]
      end

      # @param light [Stoplight::Light]
      # @param from_color [String]
      # @param to_color [String]
      # @return [void]
      def set_last_notification(light, from_color, to_color)
        @last_notifications[light.name] = [from_color, to_color]
      end

      # @param light [Stoplight::Light]
      # @return [<Stoplight::Failure>]
      def query_failures(light, time = Time.now)
        @failures[light.name].select do |failure|
          failure.time.to_i > time.to_i - light.window_size
        end
      end
    end
  end
end

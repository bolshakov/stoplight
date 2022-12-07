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

      def get_all(light, window: nil)
        synchronize do
          [
            query_failures(light, window: window),
            @states[light.name]
          ]
        end
      end

      def get_failures(light, window: nil)
        synchronize { query_failures(light, window: window) }
      end

      def record_failure(light, failure, window: nil)
        synchronize do
          @failures[light.name].unshift(failure)
          @failures[light.name] = query_failures(light, window: window).first(light.threshold)
          @failures[light.name].size
        end
      end

      def clear_failures(light, window: nil)
        synchronize do
          query_failures(light, window: window).tap do
            @failures.delete(light.name)
          end
        end
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

      private

      def query_failures(light, window:)
        if window
          window_start = Time.now - window
          @failures[light.name].select { |x| x.time >= window_start }
        else
          @failures[light.name]
        end
      end
    end
  end
end

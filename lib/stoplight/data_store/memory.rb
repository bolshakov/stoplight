# frozen_string_literal: true

require 'monitor'

module Stoplight
  module DataStore
    # Memory Data Store
    #
    # The Memory Data Store uses a hash-based approach to manage light data. It is suitable
    # for scenarios where persistence is not required, and data can be stored and managed
    # within the application's memory.
    #
    # Attributes:
    #   - @failures: Hash to store failures for each light.
    #   - @states: Hash to store the state of each light.
    #   - @last_used_at: Hash to store the last usage time for each light.
    #   - @last_notifications: Hash to store the last notification information for each light.
    #
    # @see Base
    class Memory < Base
      include MonitorMixin
      KEY_SEPARATOR = ':'
      LIGHT_EXPIRATION_TIME = 7 * 24 * 60 * 60

      def initialize
        @failures = Hash.new { |h, k| h[k] = [] }
        @states = Hash.new { |h, k| h[k] = State::UNLOCKED }
        @last_used_at = Hash.new { |h, k| h[k] = Time.now - LIGHT_EXPIRATION_TIME - 1 }
        @last_notifications = {}
        super() # MonitorMixin
      end

      # @overload names()
      #   @return [Array<String>]
      #
      # @overload names()
      #   @param used_after [Time]
      #   @return [Array<String>]
      #
      def names(used_after: Time.now - LIGHT_EXPIRATION_TIME)
        synchronize do
          @last_used_at
            .select { |_, time| time > used_after }
            .keys
        end
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

      def set_last_used_at(light, time)
        synchronize { @last_used_at[light.name] = time }
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

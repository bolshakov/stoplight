# frozen_string_literal: true

require "monitor"

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin
      KEY_SEPARATOR = ":"

      def initialize
        @failures = Hash.new { |h, k| h[k] = [] }
        @states = Hash.new { |h, k| h[k] = State::UNLOCKED }
        @notification_lock = Monitor.new
        @last_notifications = {}
        super # MonitorMixin
      end

      def names
        synchronize { @failures.keys | @states.keys }
      end

      def get_all(config)
        [
          synchronize { query_failures(config) },
          synchronize { @states[config.name] }
        ]
      end

      def get_failures(config)
        synchronize { query_failures(config) }
      end

      def record_failure(config, failure)
        synchronize do
          light_name = config.name

          @failures[light_name].unshift(failure)
          # Remove all errors happened before the retention period start
          @failures[light_name] = query_failures(config, window_size: failures_retention_period)

          query_failures(config, time: failure.time).size
        end
      end

      def clear_failures(config)
        synchronize { @failures.delete(config.name) || [] }
      end

      def get_state(config)
        synchronize { @states[config.name] }
      end

      def set_state(config, state)
        synchronize { @states[config.name] = state }
      end

      def clear_state(config)
        synchronize { @states.delete(config.name) }
      end

      def with_deduplicated_notification(config, from_color, to_color)
        notify = false
        @notification_lock.synchronize do
          if last_notification(config) != [from_color, to_color]
            set_last_notification(config, from_color, to_color)
            notify = true
          end
        end
        yield if notify
      end

      private

      # @param config [Stoplight::Light::Config]
      # @return [Array, nil]
      def last_notification(config)
        @last_notifications[config.name]
      end

      # @param config [Stoplight::Light::Config]
      # @param from_color [String]
      # @param to_color [String]
      # @return [void]
      def set_last_notification(config, from_color, to_color)
        @last_notifications[config.name] = [from_color, to_color]
      end

      # @param config [Stoplight::Light::Config]
      # @return [<Stoplight::Failure>]
      def query_failures(config, time: Time.now, window_size: config.window_size)
        @failures[config.name].select do |failure|
          failure.time.to_i > time.to_i - window_size
        end
      end
    end
  end
end

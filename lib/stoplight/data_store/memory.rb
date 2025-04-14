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
          synchronize { @states[config.name] },
        ]
      end

      def get_failures(config)
        synchronize { query_failures(config) }
      end

      def record_failure(config, failure)
        synchronize do
          light_name = config.name

          # Keep at most +config.threshold+ number of errors
          @failures[light_name] = @failures[light_name].first(config.threshold - 1)
          @failures[light_name].unshift(failure)
          # Remove all errors happened before the window start
          @failures[light_name] = query_failures(config, failure.time)
          @failures[light_name].size
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
      def query_failures(config, time = Time.now)
        @failures[config.name].select do |failure|
          failure.time.to_i > time.to_i - config.window_size
        end
      end
    end
  end
end

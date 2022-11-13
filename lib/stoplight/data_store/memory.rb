# frozen_string_literal: true

require 'monitor'

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin
      DEFAULT_JITTER = 1

      def initialize
        @failures = Hash.new { |h, k| h[k] = [] }
        @states = Hash.new { |h, k| h[k] = State::UNLOCKED }
        @correlation_flags = Hash.new { |h, k| h[k] = [] }
        super() # MonitorMixin
      end

      def names
        synchronize { @failures.keys | @states.keys }
      end

      def get_all(light)
        synchronize { [@failures[light.name], @states[light.name]] }
      end

      def get_failures(light)
        synchronize { @failures[light.name] }
      end

      def record_failure(light, failure)
        synchronize do
          n = light.threshold - 1
          @failures[light.name] = @failures[light.name].first(n)
          @failures[light.name].unshift(failure).size
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

      def check_services_correlation(light)
        synchronize do
          flag = get_setex(@correlation_flags[light.name])
          @correlation_flags[light.name] = setex('locked', DEFAULT_JITTER)

          flag.nil? ? false : true
        end
      end

      private

      def get_setex(value_array)
        synchronize do
          return if value_array.nil? || value_array.empty?

          value, time_diff, value_created_at = value_array
          if value_created_at + time_diff > Time.now.to_i
            value
          else
            value_array = []
            nil
          end
        end
      end

      def setex(value, expiration_time_diff)
        synchronize do
          [value, expiration_time_diff, Time.now.to_i]
        end
      end
    end
  end
end

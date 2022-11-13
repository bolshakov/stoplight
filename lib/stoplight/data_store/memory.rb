# frozen_string_literal: true

require 'monitor'

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin
      NOTIFIERS_LOCK_TTL = 1

      def initialize(notifiers_lock_ttl: NOTIFIERS_LOCK_TTL)
        @failures = Hash.new { |h, k| h[k] = [] }
        @states = Hash.new { |h, k| h[k] = State::UNLOCKED }
        @notification_locks = Hash.new { |h, k| h[k] = [] }
        @notifiers_lock_ttl = notifiers_lock_ttl
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

      def notification_lock(light)
        synchronize do
          lock = get_setex(@notification_locks[light.name])
          @notification_locks[light.name] = setex(1, @notifiers_lock_ttl)

          lock.nil? ? false : true
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

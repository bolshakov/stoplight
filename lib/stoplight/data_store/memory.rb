# coding: utf-8

require 'concurrent/map'
require 'monitor'

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      def initialize
        @failures = Concurrent::Map.new { [] }
        @states = Concurrent::Map.new { State::UNLOCKED }
        @lock = Monitor.new
      end

      def names
        (all_failures.keys + all_states.keys).uniq
      end

      def get_all(light)
        [get_failures(light), get_state(light)]
      end

      def get_failures(light)
        all_failures[light.name]
      end

      def record_failure(light, failure)
        @lock.synchronize do
          n = light.threshold - 1
          failures = get_failures(light).first(n).unshift(failure)
          all_failures[light.name] = failures
          failures.size
        end
      end

      def clear_failures(light)
        all_failures.delete(light.name)
      end

      def get_state(light)
        all_states[light.name]
      end

      def set_state(light, state)
        all_states[light.name] = state
      end

      def clear_state(light)
        all_states.delete(light.name)
      end

      private

      def all_failures
        @failures
      end

      def all_states
        @states
      end
    end
  end
end

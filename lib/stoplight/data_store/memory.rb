# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def get_all(light)
        [get_failures(light), get_state(light)]
      end

      def get_failures(light)
        all_failures[light.name] || []
      end

      def record_failure(light, failure)
        failures = get_failures(light).unshift(failure).first(light.threshold)
        all_failures[light.name] = failures
        failures.size
      end

      def clear_failures(light)
        failures = get_failures(light)
        all_failures.delete(light.name)
        failures
      end

      def get_state(light)
        all_states[light.name] || State::UNLOCKED
      end

      def set_state(light, state)
        all_states[light.name] = state
      end

      def clear_state(light)
        state = get_state(light)
        all_states.delete(light.name)
        state
      end

      private

      def all_failures
        @data['failures'] ||= {}
      end

      def all_states
        @data['states'] ||= {}
      end
    end
  end
end

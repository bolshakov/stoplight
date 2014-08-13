# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def names
        all_states.keys
      end

      # @group Attempts

      def attempts(name)
        all_attempts[name] || 0
      end

      def record_attempt(name)
        all_attempts[name] ||= 0
        all_attempts[name] += 1
      end

      def clear_attempts(name)
        all_attempts.delete(name)
      end

      # @group Failures

      def failures(name)
        all_failures[name] || []
      end

      def record_failure(name, error)
        all_failures[name] ||= []
        failure = Failure.new(error)
        all_failures[name].push(failure)
      end

      def clear_failures(name)
        all_failures.delete(name)
      end

      # @group State

      def state(name)
        all_states[name] || STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        all_states[name] = state
      end

      # @group Threshold

      def threshold(name)
        all_thresholds[name]
      end

      def set_threshold(name, threshold)
        all_thresholds[name] = threshold
      end

      private

      def all_attempts
        @data['attempts'] ||= {}
      end

      def all_failures
        @data['failures'] ||= {}
      end

      def all_states
        @data['states'] ||= {}
      end

      def all_thresholds
        @data['thresholds'] ||= {}
      end
    end
  end
end

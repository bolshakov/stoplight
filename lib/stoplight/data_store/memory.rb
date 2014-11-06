# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def names
        thresholds.keys
      end

      def clear_stale
        names
          .select { |name| get_failures(name).empty? }
          .each { |name| clear(name) }
      end

      def clear(name)
        clear_attempts(name)
        clear_failures(name)
        clear_state(name)
        clear_threshold(name)
        clear_timeout(name)
      end

      def sync(name)
        set_threshold(name, get_threshold(name))
      end

      def greenify(name)
        clear_attempts(name)
        clear_failures(name)
      end

      def get_color(name)
        state = get_state(name)
        threshold = get_threshold(name)
        failures = get_failures(name)
        timeout = get_timeout(name)
        DataStore.colorize(state, threshold, failures, timeout)
      end

      def get_attempts(name)
        attempts[name]
      end

      def record_attempt(name)
        attempts[name] += 1
      end

      def clear_attempts(name)
        attempts.delete(name)
      end

      def get_failures(name)
        @data.fetch(DataStore.failures_key(name), DEFAULT_FAILURES)
      end

      def record_failure(name, failure)
        DataStore.validate_failure!(failure)
        @data[DataStore.failures_key(name)] ||= DEFAULT_FAILURES.dup
        @data[DataStore.failures_key(name)].push(failure)
        @data[DataStore.failures_key(name)].size
      end

      def clear_failures(name)
        @data.delete(DataStore.failures_key(name))
      end

      def get_state(name)
        states[name]
      end

      def set_state(name, state)
        DataStore.validate_state!(state)
        states[name] = state
      end

      def clear_state(name)
        states.delete(name)
      end

      def get_threshold(name)
        thresholds[name]
      end

      def set_threshold(name, threshold)
        DataStore.validate_threshold!(threshold)
        thresholds[name] = threshold
      end

      def clear_threshold(name)
        thresholds.delete(name)
      end

      def get_timeout(name)
        timeouts[name]
      end

      def set_timeout(name, timeout)
        DataStore.validate_timeout!(timeout)
        timeouts[name] = timeout
      end

      def clear_timeout(name)
        timeouts.delete(name)
      end

      private

      # @return [Hash{String => Integer}]
      def attempts
        @data[DataStore.attempts_key] ||= Hash.new(DEFAULT_ATTEMPTS)
      end

      # @return [Hash{String => String}]
      def states
        @data[DataStore.states_key] ||= Hash.new(DEFAULT_STATE)
      end

      # @return [Hash{String => Integer}]
      def thresholds
        @data[DataStore.thresholds_key] ||= Hash.new(DEFAULT_THRESHOLD)
      end

      # @return [Hash{String => Integer}]
      def timeouts
        @data[DataStore.timeouts_key] ||= Hash.new(DEFAULT_TIMEOUT)
      end
    end
  end
end

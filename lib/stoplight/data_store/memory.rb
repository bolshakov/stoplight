# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def names
        @data.keys.map do |key|
          match = /^#{DataStore::KEY_PREFIX}:(.+):([^:]+)$/.match(key)
          match[1] if match
        end.compact.uniq
      end

      def record_failure(name, error)
        failure = Failure.new(error)
        array = @data[failure_key(name)] ||= []
        array.push(failure)
      end

      def clear_failures(name)
        @data.delete(failure_key(name))
      end

      def failures(name)
        @data[failure_key(name)] || []
      end

      def settings(name)
        @data[settings_key(name)] ||= {}
      end

      def threshold(name)
        settings(name)['threshold']
      end

      def set_threshold(name, threshold)
        settings(name)['threshold'] = threshold
      end

      def record_attempt(name)
        key = attempt_key(name)
        @data[key] ||= 0
        @data[key] += 1
      end

      def clear_attempts(name)
        @data.delete(attempt_key(name))
      end

      def attempts(name)
        @data[attempt_key(name)] || 0
      end

      def state(name)
        settings(name)['state'] || DataStore::STATE_UNLOCKED
      end

      def set_state(name, state)
        validate_state!(state)
        settings(name)['state'] = state
      end
    end
  end
end

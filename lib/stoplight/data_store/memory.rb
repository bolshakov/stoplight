# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def names
        @data.keys.map do |key|
          match = /^#{KEY_PREFIX}:(.+):([^:]+)$/.match(key)
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

      def failure_threshold(name)
        settings(name)['failure_threshold']
      end

      def set_failure_threshold(name, threshold)
        settings(name)['failure_threshold'] = threshold
      end

      def record_attempt(name)
        key = attempt_key(name)
        @data[key] ||= 0
        @data[key] += 1
      end
    end
  end
end

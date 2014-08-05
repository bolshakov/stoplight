# coding: utf-8

module Stoplight
  module DataStore
    class Memory < Base
      def initialize
        @data = {}
      end

      def [](key)
        @data[key]
      end

      def []=(key, value)
        @data[key] = value
      end

      def record_failure(name, error)
        failure = Failure.new(error)
        array = @data[failure_key(name)] ||= []
        array.push(failure)
      end

      def clear_failures(name)
        @data.delete(failure_key(name))
      end

      def record_attempt(name)
        key = attempt_key(name)
        @data[key] ||= 0
        @data[key] += 1
      end
    end
  end
end

# coding: utf-8

module Stoplight
  module DataStore
    # @abstract
    class Base
      KEY_PREFIX = 'stoplight'

      # @param key [Object]
      # @return [Object, nil]
      def [](_key)
        fail NotImplementedError
      end

      # @param key [Object]
      # @param value [Object]
      # @return [Object]
      def []=(_key, _value)
        fail NotImplementedError
      end

      def names
        fail NotImplementedError
      end

      def record_failure(_name, _error)
        fail NotImplementedError
      end

      def clear_failures(_name)
        fail NotImplementedError
      end

      def failures(_name)
        fail NotImplementedError
      end

      def failure_threshold(_name)
        fail NotImplementedError
      end

      def set_failure_threshold(_name, _threshold)
        fail NotImplementedError
      end

      def record_attempt(_name)
        fail NotImplementedError
      end

      def key(name, slug)
        [KEY_PREFIX, name, slug].join(':')
      end

      def attempt_key(name)
        key(name, 'attempts')
      end

      def failure_key(name)
        key(name, 'failures')
      end

      def failure_threshold_key(name)
        key(name, 'failure_threshold')
      end
    end
  end
end

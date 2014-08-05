# coding: utf-8

module Stoplight
  module DataStore
    # @abstract
    class Base
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

      def record_failure(_name, _error)
        fail NotImplementedError
      end

      def clear_failures(_name)
        fail NotImplementedError
      end

      def record_attempt(_name)
        fail NotImplementedError
      end

      def key(name, slug)
        "stoplight:#{name}:#{slug}"
      end

      def attempt_key(name)
        key(name, 'attempts')
      end

      def failure_key(name)
        key(name, 'failures')
      end
    end
  end
end

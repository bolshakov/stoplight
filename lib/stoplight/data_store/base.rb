# coding: utf-8

module Stoplight
  module DataStore
    class Base
      # @return [Array<String>]
      def names
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _error [Exception]
      def record_failure(_name, _error)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_failures(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return [Array<Failure>]
      def failures(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return [Integer]
      def threshold(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _threshold [Integer]
      # @return (see #threshold)
      def set_threshold(_name, _threshold)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return (see #attempts)
      def record_attempt(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_attempts(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return [Integer]
      def attempts(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return [String]
      def state(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _state [String]
      # @return [String]
      def set_state(_name, _state)
        # REVIEW: Should we clear failures here?
        fail NotImplementedError
      end

      private

      def validate_state!(state)
        return if DataStore::STATES.include?(state)
        fail ArgumentError, 'Invalid state'
      end

      def key(name, slug)
        [DataStore::KEY_PREFIX, name, slug].join(':')
      end

      def attempt_key(name)
        key(name, 'attempts')
      end

      def failure_key(name)
        key(name, 'failures')
      end

      def settings_key(name)
        key(name, 'settings')
      end
    end
  end
end

# coding: utf-8

module Stoplight
  module DataStore
    class Base
      KEY_PREFIX = 'stoplight'

      STATES = Set.new([
        STATE_LOCKED_GREEN = 'locked_green',
        STATE_LOCKED_RED = 'locked_red',
        STATE_UNLOCKED = 'unlocked'
      ]).freeze

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

      def state(_name)
        fail NotImplementedError
      end

      # REVIEW: Should we clear failures here?
      def set_state(_name, _state)
        fail NotImplementedError
      end

      private

      def validate_state!(state)
        fail ArgumentError, 'Invalid state' unless STATES.include?(state)
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

      def settings_key(name)
        key(name, 'settings')
      end
    end
  end
end

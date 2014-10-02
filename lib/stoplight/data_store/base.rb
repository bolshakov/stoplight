# coding: utf-8

module Stoplight
  module DataStore
    class Base
      # @return [Array<String>]
      def names
        fail NotImplementedError
      end

      def clear_stale
        fail NotImplementedError
      end

      # @param _name [String]
      def clear(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      def sync(_name)
        fail NotImplementedError
      end

      # @group Colors

      # @param name [String]
      # @return [Boolean]
      def green?(name)
        color = get_color(name)
        DataStore.validate_color!(color)
        color == COLOR_GREEN
      end

      # @param name [String]
      # @return [Boolean]
      def yellow?(name)
        color = get_color(name)
        DataStore.validate_color!(color)
        color == COLOR_YELLOW
      end

      # @param name [String]
      # @return [Boolean]
      def red?(name)
        color = get_color(name)
        DataStore.validate_color!(color)
        color == COLOR_RED
      end

      # @param _name [String]
      # @return [String]
      def get_color(_name)
        fail NotImplementedError
      end

      # @group Attempts

      # @param _name [String]
      # @return [Integer]
      def get_attempts(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @return [Integer]
      def record_attempt(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_attempts(_name)
        fail NotImplementedError
      end

      # @group Failures

      # @param _name [String]
      # @return [Array<Failure>]
      def get_failures(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _failure [Failure]
      # @return [Failure]
      def record_failure(_name, _failure)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_failures(_name)
        fail NotImplementedError
      end

      # @group States

      # @param _name [String]
      # @return [String]
      def get_state(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _state [String]
      # @return [String]
      def set_state(_name, _state)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_state(_name)
        fail NotImplementedError
      end

      # @group Thresholds

      # @param _name [String]
      # @return [Integer]
      def get_threshold(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _threshold [Integer]
      # @return [Integer]
      def set_threshold(_name, _threshold)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_threshold(_name)
        fail NotImplementedError
      end

      # @group Timeouts

      # @param _name [String]
      # @return [Integer]
      def get_timeout(_name)
        fail NotImplementedError
      end

      # @param _name [String]
      # @param _timeout [Integer]
      # @return [Integer]
      def set_timeout(_name, _timeout)
        fail NotImplementedError
      end

      # @param _name [String]
      def clear_timeout(_name)
        fail NotImplementedError
      end
    end
  end
end

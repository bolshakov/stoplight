# frozen_string_literal: true

module Stoplight
  module DataStore
    # @abstract
    class Base
      # @return [Array<String>]
      def names
        raise NotImplementedError
      end

      # @param _light [Light]
      # @return [Array(Array<Failure>, String)]
      # @param window [Integer, nil]
      def get_all(_light, window: nil)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param window [Integer, nil]
      # @return [Array<Failure>]
      def get_failures(_light, window: nil)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param _failure [Failure]
      # @param window [Integer, nil]
      # @return [Fixnum]
      def record_failure(_light, _failure, window: nil)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param window [Integer, nil]
      # @return [Array<Failure>]
      def clear_failures(_light, window: nil)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @return [String]
      def get_state(_light)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param _state [String]
      # @return [String]
      def set_state(_light, _state)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @return [String]
      def clear_state(_light)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param _from_color [String]
      # @param _to_color [String]
      # @yield _block
      # @return [Void]
      def with_notification_lock(_light, _from_color, _to_color, &_block)
        raise NotImplementedError
      end
    end
  end
end

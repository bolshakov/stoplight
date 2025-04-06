# frozen_string_literal: true

module Stoplight
  module DataStore
    # @abstract
    class Base
      # @return [Array<String>]
      def names
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @return [Array(Array<Failure>, String)]
      def get_all(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @return [Array<Failure>]
      def get_failures(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @param _failure [Failure]
      # @return [Fixnum]
      def record_failure(_config, _failure)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @return [Array<Failure>]
      def clear_failures(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @return [String]
      def get_state(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @param _state [String]
      # @return [String]
      def set_state(_config, _state)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @return [String]
      def clear_state(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Config]
      # @param _from_color [String]
      # @param _to_color [String]
      # @yield _block
      # @return [Void]
      def with_notification_lock(_config, _from_color, _to_color, &_block)
        raise NotImplementedError
      end
    end
  end
end

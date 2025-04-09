# frozen_string_literal: true

module Stoplight
  module DataStore
    # @abstract
    class Base
      # @return [Array<String>]
      def names
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @return [Array(Array<Failure>, String)]
      def get_all(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @return [Array<Failure>]
      def get_failures(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @param _failure [Failure]
      # @return [Fixnum]
      def record_failure(_config, _failure)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @return [Array<Failure>]
      def clear_failures(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @return [String]
      def get_state(_config)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @param _state [String]
      # @return [String]
      def set_state(_config, _state)
        raise NotImplementedError
      end

      # @param _config [Stoplight::Light::Config]
      # @return [String]
      def clear_state(_config)
        raise NotImplementedError
      end

      # Executes the provided block only if the given color transition (from_color → to_color)
      # hasn't been recently processed, preventing duplicate notifications across distributed servers.
      #
      # @example
      #   with_deduplicated_notification(config, Color::GREEN, Color::RED) do
      #     send_alert_email("Service #{config.name} is down!")
      #   end
      #
      # @param _config [Stoplight::Light::Config] the light configuration
      # @param _from_color [String] the initial color state (e.g., Color::GREEN)
      # @param _to_color [String] the new color state (e.g., Color::RED)
      # @yield Executes the block if this is a new or expired transition
      # @return [void]
      def with_deduplicated_notification(_config, _from_color, _to_color, &_block)
        raise NotImplementedError
      end
    end
  end
end

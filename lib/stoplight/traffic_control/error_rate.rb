# frozen_string_literal: true

module Stoplight
  module TrafficControl
    # Compatibility:
    #   This strategy only compatible with stoplights that track errors over a running window.
    #
    class ErrorRate < Base
      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::Config::CompatibilityResult]
      def check_compatibility(config)
        if config.window_size.nil?
          incompatible("`window_size` should be set")
        else
          compatible
        end
      end

      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean]
      def stop_traffic?(config, metadata)
        super
      end
    end
  end
end

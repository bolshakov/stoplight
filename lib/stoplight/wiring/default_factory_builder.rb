# frozen_string_literal: true

module Stoplight
  module Wiring
    # Builds the default LightFactory from user-provided configuration which is
    # used as the basis for all circuit breakers.
    #
    class DefaultFactoryBuilder
      attr_reader :configuration

      def initialize
        @configuration = DefaultConfiguration.new
      end

      def build
        LightFactory.new(settings: configuration.to_settings)
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Error
    class Base < StandardError
    end

    class UnregisteredLightError < Base
    end

    class ConfigurationError < Base
    end

    class IncorrectColor < Base
    end

    class TooManySubscriptions < Base
    end

    class RedLight < Base
      # @!attribute light_name
      #   @return [String] The light's name
      attr_reader :light_name

      # @!attribute cool_off_time
      #   @return [Numeric] Cool-off period in seconds
      attr_reader :cool_off_time

      # @!attribute retry_after
      #   @return [Time | nil] Absolute Time after which a recovery attempt can occur
      #     could be nil if the light is locked red
      attr_reader :retry_after

      # Initializes a new RedLight error.
      #
      # @param light_name [String] The light's name
      #
      # @option cool_off_time [Numeric] Cool-off period in seconds
      #
      # @option retry_after [Time | nil] Absolute Time after which a recovery attempt can occur
      #
      # @return [Stoplight::Error::RedLight]
      def initialize(light_name, cool_off_time:, retry_after:)
        @light_name = light_name
        @cool_off_time = cool_off_time
        @retry_after = retry_after

        super(light_name)
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Error
    Base = Class.new(StandardError)
    ConfigurationError = Class.new(Base)
    IncorrectColor = Class.new(Base)
    class RedLight < Base
      # @!attribute light_name
      #   @return [String] The light's name
      attr_reader :light_name

      # @!attribute cool_off_time
      #   @return [Numeric] Cool-off period in seconds
      attr_reader :cool_off_time

      # @!attribute retry_after
      #   @return [Time] Absolute Time after which a recovery attempt can occur
      attr_reader :retry_after

      # Initializes a new RedLight error.
      #
      # @param light_name [String] The light's name
      #
      # @option cool_off_time [Numeric] Cool-off period in seconds
      #
      # @option retry_after [Time] Absolute Time after which a recovery attempt can occur
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

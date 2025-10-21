# frozen_string_literal: true

module Stoplight
  module Error
    Base = Class.new(StandardError)
    ConfigurationError = Class.new(Base)
    IncorrectColor = Class.new(Base)
    class RedLight < Base
      attr_reader :light_name      # The circuit breaker's name
      attr_reader :cool_off_time   # Cool-off period in seconds
      attr_reader :retry_after     # Absolute Time when recovery will be attempted

      def initialize(light_name, cool_off_time:, retry_after:)
        @light_name = light_name
        @cool_off_time = cool_off_time
        @retry_after = retry_after

        super(light_name)
      end
    end
  end
end

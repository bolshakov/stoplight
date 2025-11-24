# frozen_string_literal: true

module Stoplight
  module Domain
    # A +Stoplight::Light+ configuration object.
    #
    # # @!attribute [r] name
    #   @return [String]
    #
    # @!attribute [r] cool_off_time - cool-off time in seconds
    #   @return [Numeric]
    #
    # @!attribute [r] threshold
    #   @return [Numeric]
    #
    # @!attribute [r] window_size
    #   @return [Numeric]
    #
    # @!attribute [r] tracked_errors
    #   @return [Array<StandardError>]
    #
    # @!attribute [r] skipped_errors
    #  @return [Array<Exception>]
    #
    # @api private
    Config = Data.define(
      :name,
      :cool_off_time,
      :threshold,
      :recovery_threshold,
      :window_size,
      :tracked_errors,
      :skipped_errors
    ) do
      class << self
        # Creates a new NULL configuration object.
        # @return [Stoplight::Domain::Config]
        def empty
          new(**members.map { |key| [key, nil] }.to_h)
        end
      end

      # Checks if the given error should be tracked
      #
      # @param error [#==] The error to check, e.g. an Exception, Class or Proc
      # @return [Boolean]
      def track_error?(error)
        skip = skipped_errors.any? { |klass| klass === error }
        track = tracked_errors.any? { |klass| klass === error }

        !skip && track
      end

      def cool_off_time_in_milliseconds
        cool_off_time * 1_000
      end
    end
  end
end

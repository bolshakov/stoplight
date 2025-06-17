# frozen_string_literal: true

module Stoplight
  class Light
    # A +Stoplight::Light+ configuration object.
    #
    # # @!attribute [r] name
    #   @return [String]
    #
    # @!attribute [r] cool_off_time
    #   @return [Numeric]
    #
    # @!attribute [r] data_store
    #   @return [Stoplight::DataStore::Base]
    #
    # @!attribute [r] error_notifier
    #   @return [StandardError => void]
    #
    # @!attribute [r] notifiers
    #   @return [Array<Stoplight::Notifier::Base>]
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
    # @!attribute [r] traffic_control
    #  @return [Stoplight::TrafficControl::Base]
    #
    # @!attribute [r] traffic_recovery
    #   @return [Stoplight::TrafficRecovery::Base]
    # @api private
    Config = Data.define(
      :name,
      :cool_off_time,
      :data_store,
      :error_notifier,
      :notifiers,
      :threshold,
      :window_size,
      :tracked_errors,
      :skipped_errors,
      :traffic_control,
      :traffic_recovery
    ) do
      # Checks if the given error should be tracked
      #
      # @param error [#==] The error to check, e.g. an Exception, Class or Proc
      # @return [Boolean]
      def track_error?(error)
        skip = skipped_errors.any? { |klass| klass === error }
        track = tracked_errors.any? { |klass| klass === error }

        !skip && track
      end
    end
  end
end

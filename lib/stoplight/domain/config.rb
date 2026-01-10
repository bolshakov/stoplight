# frozen_string_literal: true

module Stoplight
  module Domain
    # A +Stoplight::Light+ configuration object.
    #
    # @api private
    Config = Data.define(
      :name,
      :cool_off_time,
      :threshold,
      :recovery_threshold,
      :window_size,
      :tracked_errors,
      :skipped_errors,
      :traffic_control,
      :traffic_recovery,
      :error_notifier,
      :notifiers,
      :data_store
    )
    class Config
      # Checks if the given error should be tracked
      #
      # @param error The error to check, e.g. an Exception, Class or Proc
      # @return [Boolean]
      def track_error?(error)
        skip = skipped_errors.any? { |matcher| matcher === error }
        track = tracked_errors.any? { |matcher| matcher === error }

        !skip && track
      end

      def cool_off_time_in_milliseconds
        (cool_off_time * 1_000).to_i
      end
    end
  end
end

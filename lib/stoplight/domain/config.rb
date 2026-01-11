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
      def cool_off_time_in_milliseconds
        (cool_off_time * 1_000).to_i
      end
    end
  end
end

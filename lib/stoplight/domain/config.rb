# frozen_string_literal: true

module Stoplight
  module Domain
    # A +Stoplight::Light+ configuration object.
    #
    # @api private
    Config = Data.define(
      :id,
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

      def with(
        id: T.undefined,
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        skipped_errors: T.undefined,
        tracked_errors: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        data_store: T.undefined
      )
        super(
          id: id.is_a?(Undefined) ? self.id : id,
          name: name.is_a?(Undefined) ? self.name : name,
          cool_off_time: cool_off_time.is_a?(Undefined) ? self.cool_off_time : cool_off_time,
          threshold: threshold.is_a?(Undefined) ? self.threshold : threshold,
          recovery_threshold: recovery_threshold.is_a?(Undefined) ? self.recovery_threshold : recovery_threshold,
          window_size: window_size.is_a?(Undefined) ? self.window_size : window_size,
          skipped_errors: skipped_errors.is_a?(Undefined) ? self.skipped_errors : skipped_errors,
          tracked_errors: tracked_errors.is_a?(Undefined) ? self.tracked_errors : tracked_errors,
          traffic_control: traffic_control.is_a?(Undefined) ? self.traffic_control : traffic_control,
          traffic_recovery: traffic_recovery.is_a?(Undefined) ? self.traffic_recovery : traffic_recovery,
          error_notifier: error_notifier.is_a?(Undefined) ? self.error_notifier : error_notifier,
          notifiers: notifiers.is_a?(Undefined) ? self.notifiers : notifiers,
          data_store: data_store.is_a?(Undefined) ? self.data_store : data_store,
        )
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module DataStore
    Metadata = Data.define(
      :window_end,
      :window_size,
      :successes,
      :failures,
      :recovery_probe_successes,
      :recovery_probe_failures,
      :last_failure_at,
      :last_success_at,
      :consecutive_failures,
      :consecutive_successes,
      :recovery_started_at,
      :last_failure,
      :last_breach_at,
      :locked_state,
      :recovery_scheduled_after
    ) do
      class << self
        def empty
          new(
            window_end: nil,
            window_size: nil,
            successes: 0,
            failures: 0,
            recovery_probe_successes: 0,
            recovery_probe_failures: 0,
            last_failure_at: nil,
            last_success_at: nil,
            consecutive_failures: 0,
            consecutive_successes: 0,
            last_failure: nil,
            recovery_started_at: nil,
            last_breach_at: nil,
            locked_state: nil,
            recovery_scheduled_after: nil
          )
        end
      end
      def initialize(
        window_end:,
        window_size:,
        successes:,
        failures:,
        recovery_probe_successes:,
        recovery_probe_failures:,
        last_failure_at: nil,
        last_success_at: nil,
        consecutive_failures: 0,
        consecutive_successes: 0,
        last_failure: nil,
        recovery_started_at: nil,
        last_breach_at: nil,
        locked_state: nil,
        recovery_scheduled_after: nil
      )
        super(
          window_end:, window_size:,
          recovery_probe_successes: Integer(recovery_probe_successes),
          recovery_probe_failures: Integer(recovery_probe_failures),
          successes: Integer(successes),
          failures: Integer(failures),
          last_failure_at: (Time.at(Integer(last_failure_at)) if last_failure_at),
          last_success_at: (Time.at(Integer(last_success_at)) if last_success_at),
          consecutive_failures: Integer(consecutive_failures),
          consecutive_successes: Integer(consecutive_successes),
          last_failure:,
          recovery_started_at: (Time.at(Integer(recovery_started_at)) if recovery_started_at),
          last_breach_at: (Time.at(Integer(last_breach_at)) if last_breach_at),
          locked_state: locked_state || State::UNLOCKED,
          recovery_scheduled_after: (Time.at(Integer(recovery_scheduled_after)) if recovery_scheduled_after),
        )
      end
    end
  end
end

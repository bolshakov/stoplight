# frozen_string_literal: true

module Stoplight
  # @api private
  Metadata = Data.define(
    :successes,
    :failures,
    :recovery_probe_successes,
    :recovery_probe_failures,
    :last_failure_at,
    :last_success_at,
    :consecutive_failures,
    :consecutive_successes,
    :last_failure,
    :breached_at,
    :locked_state,
    :recovery_scheduled_after,
    :recovery_started_at,
    :recovered_at
  ) do
    class << self
      def empty
        new(
          successes: nil,
          failures: nil,
          recovery_probe_successes: nil,
          recovery_probe_failures: nil,
          last_failure_at: nil,
          last_success_at: nil,
          consecutive_failures: 0,
          consecutive_successes: 0,
          last_failure: nil,
          breached_at: nil,
          locked_state: nil,
          recovery_started_at: nil,
          recovery_scheduled_after: nil,
          recovered_at: nil
        )
      end
    end
    def initialize(
      successes:,
      failures:,
      recovery_probe_successes:,
      recovery_probe_failures:,
      last_failure_at: nil,
      last_success_at: nil,
      consecutive_failures: 0,
      consecutive_successes: 0,
      last_failure: nil,
      breached_at: nil,
      locked_state: nil,
      recovery_started_at: nil,
      recovery_scheduled_after: nil,
      recovered_at: nil
    )
      super(
        recovery_probe_successes:,
        recovery_probe_failures:,
        successes:,
        failures:,
        last_failure_at: (Time.at(Integer(last_failure_at)) if last_failure_at),
        last_success_at: (Time.at(Integer(last_success_at)) if last_success_at),
        consecutive_failures: Integer(consecutive_failures),
        consecutive_successes: Integer(consecutive_successes),
        last_failure:,
        breached_at: (Time.at(Integer(breached_at)) if breached_at),
        locked_state: locked_state || State::UNLOCKED,
        recovery_scheduled_after: (Time.at(Integer(recovery_scheduled_after)) if recovery_scheduled_after),
        recovery_started_at: (Time.at(Integer(recovery_started_at)) if recovery_started_at),
        recovered_at: (Time.at(Integer(recovered_at)) if recovered_at),
      )
    end
  end
end

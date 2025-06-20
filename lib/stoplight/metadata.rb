# frozen_string_literal: true

module Stoplight
  # @api private
  Metadata = Data.define(
    :successes,
    :errors,
    :recovery_probe_successes,
    :recovery_probe_errors,
    :last_error_at,
    :last_success_at,
    :consecutive_errors,
    :consecutive_successes,
    :last_error,
    :breached_at,
    :locked_state,
    :recovery_scheduled_after,
    :recovery_started_at,
    :recovered_at
  ) do
    def initialize(
      successes: nil,
      errors: nil,
      recovery_probe_successes: nil,
      recovery_probe_errors: nil,
      last_error_at: nil,
      last_success_at: nil,
      consecutive_errors: 0,
      consecutive_successes: 0,
      last_error: nil,
      breached_at: nil,
      locked_state: nil,
      recovery_started_at: nil,
      recovery_scheduled_after: nil,
      recovered_at: nil
    )
      super(
        recovery_probe_successes:,
        recovery_probe_errors:,
        successes:,
        errors:,
        last_error_at: (Time.at(Integer(last_error_at)) if last_error_at),
        last_success_at: (Time.at(Integer(last_success_at)) if last_success_at),
        consecutive_errors: Integer(consecutive_errors),
        consecutive_successes: Integer(consecutive_successes),
        last_error:,
        breached_at: (Time.at(Integer(breached_at)) if breached_at),
        locked_state: locked_state || State::UNLOCKED,
        recovery_scheduled_after: (Time.at(Integer(recovery_scheduled_after)) if recovery_scheduled_after),
        recovery_started_at: (Time.at(Integer(recovery_started_at)) if recovery_started_at),
        recovered_at: (Time.at(Integer(recovered_at)) if recovered_at),
      )
    end

    # @param at [Time] (Time.now) the moment of time when the color is determined
    # @return [String] one of +Color::GREEN+, +Color::RED+, or +Color::YELLOW+
    def color(at: Time.now)
      if locked_state == State::LOCKED_GREEN
        Color::GREEN
      elsif locked_state == State::LOCKED_RED
        Color::RED
      elsif (recovery_scheduled_after && recovery_scheduled_after < at) || recovery_started_at
        Color::YELLOW
      elsif breached_at
        Color::RED
      else
        Color::GREEN
      end
    end

    # Calculates the error rate based on the number of successes and errors.
    #
    # @return [Float]
    def error_rate
      if successes.nil? || errors.nil? || (successes + errors).zero?
        0.0
      else
        errors.fdiv(successes + errors)
      end
    end

    # @return [Integer]
    def requests
      successes + errors
    end
  end
end

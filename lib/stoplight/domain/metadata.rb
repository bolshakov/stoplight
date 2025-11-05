# frozen_string_literal: true

module Stoplight
  module Domain
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
      :recovered_at,
      :current_time
    ) do
      # YELLOW color could be entered implicitly through a timeout
      # and explicitly through a transition.
      #
      # This method indicates whether the recovery has already started explicitly
      #
      # @return [Boolean]
      def recovery_started?
        recovery_started_at && recovery_started_at <= current_time
      end

      # @return [String] one of +Color::GREEN+, +Color::RED+, or +Color::YELLOW+
      def color
        if locked_state == State::LOCKED_GREEN
          Color::GREEN
        elsif locked_state == State::LOCKED_RED
          Color::RED
        elsif (recovery_scheduled_after && recovery_scheduled_after < current_time) || recovery_started_at
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
        if (successes + errors).zero?
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
end

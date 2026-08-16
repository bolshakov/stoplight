# frozen_string_literal: true

module Stoplight
  module Domain
    StateSnapshot = Data.define(
      :breached_at,
      :locked_state,
      :recovery_scheduled_after,
      :recovery_started_at,
      :time
    )

    class StateSnapshot
      # @!attribute breached_at
      #   The time when the light became red (breached threshold)
      #
      # @!attribute recovery_scheduled_after
      #   When Light transitions to RED, it schedules recovery after the Cool Off Time.
      #
      # @!attribute recovery_started_at
      #   When in YELLOW state, this time indicates the time of transitioning to YELLOW
      #
      # @!attribute time
      #   The time when the snapshot was taken

      # @return [String] one of +Color::GREEN+, +Color::RED+, or +Color::YELLOW+
      def color
        if locked_state == State::LOCKED_GREEN
          Color::GREEN
        elsif locked_state == State::LOCKED_RED
          Color::RED
        elsif (recovery_scheduled_after && recovery_scheduled_after! < time) || recovery_started?
          Color::YELLOW
        elsif breached_at
          Color::RED
        else
          Color::GREEN
        end
      end

      # YELLOW color could be entered implicitly through a timeout
      # and explicitly through a transition.
      #
      # This method indicates whether the recovery has already started explicitly
      #
      def recovery_started?
        if recovery_started_at.nil?
          false
        else
          recovery_started_at! <= time
        end
      end

      def recovery_started_at!
        recovery_started_at or raise TypeError, "recovery_started_at must not be nil"
      end

      def recovery_scheduled_after!
        recovery_scheduled_after or raise TypeError, "recovery_scheduled_after must not be nil"
      end
    end
  end
end

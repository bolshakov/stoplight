# frozen_string_literal: true

module Stoplight
  module Domain
    # Pins a light to a color (or releases the pin), writing the lock state and emitting +Telemetry::LockChanged+.
    #
    # @example
    #   lock_control = Stoplight::Domain::LockControl.new(state_store:, emitter:)
    #   lock_control.lock(Stoplight::Color::RED)
    #   lock_control.unlock
    #
    # @api private
    class LockControl
      def initialize(state_store:, emitter:)
        @state_store = state_store
        @emitter = emitter
      end

      # @param color - +Color::RED+ or +Color::GREEN+
      # @raise [Stoplight::Error::IncorrectColor] for any other color
      def lock(color)
        state = case color
        when Color::RED then State::LOCKED_RED
        when Color::GREEN then State::LOCKED_GREEN
        else raise Error::IncorrectColor
        end

        @emitter.emit(Telemetry::LockChanged) do
          state_snapshot = @state_store.state_snapshot

          Telemetry::LockChanged.new(from_color: state_snapshot.color, to_color: color,
            from_state: state_snapshot.locked_state, to_state: state)
        end

        @state_store.set_state(state)
      end

      def unlock
        @emitter.emit(Telemetry::LockChanged) do
          state_snapshot = @state_store.state_snapshot
          from_color = state_snapshot.color
          from_state = state_snapshot.locked_state
          to_state = State::UNLOCKED
          # Reuses StateSnapshot#color instead of re-deriving it: unlocking can reveal a
          # breach/recovery color that isn't RED or GREEN, unlike a lock's fixed color.
          to_color = state_snapshot.with(locked_state: to_state).color

          Telemetry::LockChanged.new(from_color:, to_color:, from_state:, to_state:)
        end

        @state_store.set_state(State::UNLOCKED)
      end
    end
  end
end

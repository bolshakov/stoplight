# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Memory
        # Thread-safe in-memory state storage for a single light.
        #
        # Manages light state transitions and ensures notification
        # deduplication through atomic transition detection. Each transition
        # method returns whether the calling thread was first to trigger that
        # transition, enabling exactly-once notification semantics.
        #
        # @example Basic usage
        #   state = State.new(clock: SystemClock.new, cool_off_time: 60)
        #
        #   # Multiple threads may call this concurrently
        #   if state.transition_to_color(Domain::Color::RED)
        #     # Only one thread reaches here - send notification
        #     notifier.notify(circuit_name, :opened)
        #   end
        #
        # @example Inspecting current state
        #   snapshot = state.state_snapshot
        #   snapshot.locked_state        # => "unlocked"
        #   snapshot.breached_at         # => 2025-01-15 10:30:00 UTC
        #   snapshot.recovery_scheduled_after  # => 2025-01-15 10:31:00 UTC
        #
        # @see Stoplight::Domain::StateSnapshot for the structure of state snapshots
        # @see Stoplight::Domain::Storage::State for the interface contract
        #
        class State < Domain::Storage::State
          # @!attribute recovered_at
          #   @return [Time, nil]
          private attr_accessor :recovered_at

          # @!attribute locked_state
          #   @return [String]
          private attr_accessor :locked_state

          # @!attribute recovery_scheduled_after
          #   @return [Time, nil]
          private attr_accessor :recovery_scheduled_after

          # @!attribute recovery_started_at
          #   @return [Time, nil]
          private attr_accessor :recovery_started_at

          # @!attribute breached_at
          #   @return [Time, nil]
          private attr_accessor :breached_at

          # @!attribute mutex
          #   @return [Thread::Mutex]
          private attr_reader :mutex

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          # @!attribute cool_off_time
          #   @return [Integer]
          private attr_reader :cool_off_time

          # @param clock [Stoplight::Domain::Clock]
          # @param cool_off_time [Integer]
          def initialize(clock:, cool_off_time:)
            @locked_state = Stoplight::State::UNLOCKED
            @mutex = Thread::Mutex.new
            @clock = clock
            @cool_off_time = cool_off_time
          end

          # @param state [String]
          # @return [void]
          def set_state(state)
            mutex.synchronize do
              self.locked_state = state
            end
          end

          # @return [Stoplight::Domain::StateSnapshot]
          def state_snapshot
            mutex.synchronize do
              Domain::StateSnapshot.new(
                time: clock.current_time,
                locked_state:,
                recovery_scheduled_after:,
                recovery_started_at:,
                breached_at:
              )
            end
          end

          # Combined method that performs the state transition based on color
          #
          # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
          # @return [Boolean] true if this is the first instance to detect this transition
          def transition_to_color(color)
            case color
            when Domain::Color::GREEN
              transition_to_green
            when Domain::Color::YELLOW
              transition_to_yellow
            when Domain::Color::RED
              transition_to_red
            else
              raise ArgumentError, "Invalid color: #{color}"
            end
          end

          # @return [void]
          def clear
            mutex.synchronize do
              self.locked_state = Stoplight::State::UNLOCKED
              self.recovered_at = nil
              self.recovery_scheduled_after = nil
              self.breached_at = nil
              self.recovery_started_at = nil
            end
          end

          # Transitions to GREEN state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_green
            mutex.synchronize do
              if recovered_at
                false
              else
                self.recovered_at = clock.current_time
                self.recovery_started_at = nil
                self.breached_at = nil
                self.recovery_scheduled_after = nil
                true
              end
            end
          end

          # Transitions to YELLOW (recovery) state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_yellow
            mutex.synchronize do
              if recovery_started_at.nil?
                self.recovery_started_at = clock.current_time
                self.recovery_scheduled_after = nil
                self.recovered_at = nil
                self.breached_at = nil
                true
              else
                self.recovery_scheduled_after = nil
                self.recovered_at = nil
                self.breached_at = nil
                false
              end
            end
          end

          # Transitions to RED state and ensures only one notification
          #
          # @return [Boolean] true if this is the first instance to detect this transition
          private def transition_to_red
            mutex.synchronize do
              current_time = clock.current_time

              self.recovery_scheduled_after = current_time + cool_off_time
              self.recovery_started_at = nil
              self.recovered_at = nil

              if breached_at
                false
              else
                self.breached_at = current_time
                true
              end
            end
          end
        end
      end
    end
  end
end

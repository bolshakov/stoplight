# frozen_string_literal: true

require "monitor"

module Stoplight
  module Infrastructure
    module DataStore
      # @see +Domain::DataStore+
      class Memory < Domain::DataStore
        include MonitorMixin

        KEY_SEPARATOR = ":"

        # @!attribute recovery_lock_store
        #   @return [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockStore]
        #   @api private
        private attr_reader :recovery_lock_store

        # @!attribute clock
        #   @return [Stoplight::Domain::Clock]
        private attr_reader :clock

        # @param recovery_lock_store [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockStore]
        def initialize(recovery_lock_store:, clock:)
          @clock = clock
          @recovery_lock_store = recovery_lock_store
          @errors = Hash.new { |errors, light_name| errors[light_name] = SlidingWindow.new(clock:) }
          @successes = Hash.new { |successes, light_name| successes[light_name] = SlidingWindow.new(clock:) }
          @metrics = Hash.new { |metrics, light_name| metrics[light_name] = Metrics.new }

          @recovery_metrics = Hash.new { |metrics, light_name| metrics[light_name] = Metrics.new }

          @states = Hash.new { |states, light_name| states[light_name] = State.new }

          super() # MonitorMixin
        end

        # @return [Array<String>]
        def names
          synchronize { @metrics.keys | @states.keys | @recovery_metrics.keys }
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::Metrics]
        def get_metrics(config)
          light_name = config.name

          synchronize do
            current_time = self.current_time
            window_start = if config.window_size
              (current_time - config.window_size)
            else
              current_time
            end

            metrics = @metrics[light_name]

            errors = @errors[light_name].sum_in_window(window_start) if config.window_size
            successes = @successes[light_name].sum_in_window(window_start) if config.window_size
            consecutive_errors = config.window_size ? [metrics.consecutive_errors, errors].min : metrics.consecutive_errors
            consecutive_successes = config.window_size ? [metrics.consecutive_successes.to_i, successes].min : metrics.consecutive_successes.to_i

            Domain::Metrics.new(
              errors:,
              successes:,
              consecutive_errors:,
              consecutive_successes:,
              last_error: metrics.last_error,
              last_success_at: metrics.last_success_at
            )
          end
        end

        # @return [Stoplight::Domain::Metrics]
        def get_recovery_metrics(config)
          light_name = config.name

          synchronize do
            metrics = @recovery_metrics[light_name]

            Domain::Metrics.new(
              errors: nil, successes: nil,
              consecutive_errors: metrics.consecutive_errors,
              consecutive_successes: metrics.consecutive_successes,
              last_error: metrics.last_error,
              last_success_at: metrics.last_success_at
            )
          end
        end

        # @return [Stoplight::Domain::StateSnapshot]
        def get_state_snapshot(config)
          time, state = synchronize do
            [current_time, @states[config.name]]
          end

          Domain::StateSnapshot.new(
            time:,
            locked_state: state.locked_state,
            recovery_scheduled_after: state.recovery_scheduled_after,
            recovery_started_at: state.recovery_started_at,
            breached_at: state.breached_at
          )
        end

        # @param config [Stoplight::Domain::Config]
        # @param exception [Exception]
        # @return [void]
        def record_failure(config, exception)
          current_time = self.current_time
          light_name = config.name
          failure = Domain::Failure.from_error(exception, time: current_time)

          synchronize do
            @errors[light_name].increment if config.window_size

            metrics = @metrics[light_name]

            if metrics.last_error_at.nil? || failure.occurred_at > metrics.last_error_at
              metrics.last_error = failure
            end

            metrics.consecutive_errors += 1
            metrics.consecutive_successes = 0
          end
        end

        def clear_metrics(config)
          light_name = config.name
          synchronize do
            if config.window_size
              @errors[light_name] = SlidingWindow.new(clock:)
              @successes[light_name] = SlidingWindow.new(clock:)
            end
            @metrics[light_name] = Metrics.new
          end
        end

        def clear_recovery_metrics(config)
          synchronize do
            @recovery_metrics[config.name] = Metrics.new
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def record_success(config)
          light_name = config.name
          current_time = self.current_time

          synchronize do
            @successes[light_name].increment if config.window_size

            metrics = @metrics[light_name]

            if metrics.last_success_at.nil? || current_time > metrics.last_success_at
              metrics.last_success_at = current_time
            end

            metrics.consecutive_errors = 0
            metrics.consecutive_successes += 1
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @param exception [Exception]
        # @return [void]
        def record_recovery_probe_failure(config, exception)
          light_name = config.name
          current_time = self.current_time
          failure = Domain::Failure.from_error(exception, time: current_time)

          synchronize do
            metrics = @recovery_metrics[light_name]

            if metrics.last_error_at.nil? || failure.occurred_at > metrics.last_error_at
              metrics.last_error = failure
            end

            metrics.consecutive_errors += 1
            metrics.consecutive_successes = 0
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def record_recovery_probe_success(config)
          light_name = config.name
          current_time = self.current_time

          synchronize do
            metrics = @recovery_metrics[light_name]
            if metrics.last_success_at.nil? || current_time > metrics.last_success_at
              metrics.last_success_at = current_time
            end

            metrics.consecutive_errors = 0
            metrics.consecutive_successes += 1
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @param state [String]
        # @return [String]
        def set_state(config, state)
          light_name = config.name

          synchronize do
            @states[light_name].locked_state = state
          end
          state
        end

        # @return [String]
        def inspect
          "#<#{self.class.name}>"
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def delete_light(config)
          light_name = config.name

          synchronize do
            @states.delete(light_name)
            @recovery_metrics.delete(light_name)
            @metrics.delete(light_name)
            @errors.delete(light_name)
            @successes.delete(light_name)
          end
        end

        # Combined method that performs the state transition based on color
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
        # @return [Boolean] true if this is the first instance to detect this transition
        def transition_to_color(config, color)
          case color
          when Domain::Color::GREEN
            transition_to_green(config)
          when Domain::Color::YELLOW
            transition_to_yellow(config)
          when Domain::Color::RED
            transition_to_red(config)
          else
            raise ArgumentError, "Invalid color: #{color}"
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockToken, nil]
        def acquire_recovery_lock(config)
          recovery_lock_store.acquire_lock(config.name)
        end

        # @param lock [Stoplight::Infrastructure::DataStore::Memory::RecoveryLockToken]
        # @return [void]
        def release_recovery_lock(lock)
          recovery_lock_store.release_lock(lock)
        end

        # Transitions to GREEN state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_green(config)
          light_name = config.name
          current_time = self.current_time

          synchronize do
            state = @states[light_name]

            if state.recovered_at
              false
            else
              state.recovered_at = current_time
              state.recovery_started_at = nil
              state.breached_at = nil
              state.recovery_scheduled_after = nil
              true
            end
          end
        end

        # Transitions to YELLOW (recovery) state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_yellow(config)
          light_name = config.name
          current_time = self.current_time

          synchronize do
            state = @states[light_name]
            if state.recovery_started_at.nil?
              state.recovery_started_at = current_time
              state.recovery_scheduled_after = nil
              state.recovered_at = nil
              state.breached_at = nil
              true
            else
              state.recovery_scheduled_after = nil
              state.recovered_at = nil
              state.breached_at = nil
              false
            end
          end
        end

        # Transitions to RED state and ensures only one notification
        #
        # @param config [Stoplight::Domain::Config] The light configuration
        # @return [Boolean] true if this is the first instance to detect this transition
        private def transition_to_red(config)
          light_name = config.name
          current_time = self.current_time
          recovery_scheduled_after = current_time + config.cool_off_time

          synchronize do
            state = @states[light_name]
            if state.breached_at
              state.recovery_scheduled_after = recovery_scheduled_after
              state.recovery_started_at = nil
              state.recovered_at = nil
              false
            else
              state.breached_at = current_time
              state.recovery_scheduled_after = recovery_scheduled_after
              state.recovery_started_at = nil
              state.recovered_at = nil
              true
            end
          end
        end

        private def current_time
          Time.now
        end
      end
    end
  end
end

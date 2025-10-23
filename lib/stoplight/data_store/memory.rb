# frozen_string_literal: true

require "monitor"

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin

      KEY_SEPARATOR = ":"

      def initialize
        @errors = Hash.new { |errors, light_name| errors[light_name] = SlidingWindow.new }
        @successes = Hash.new { |successes, light_name| successes[light_name] = SlidingWindow.new }

        @recovery_probe_errors = Hash.new { |recovery_probe_errors, light_name| recovery_probe_errors[light_name] = SlidingWindow.new }
        @recovery_probe_successes = Hash.new { |recovery_probe_successes, light_name| recovery_probe_successes[light_name] = SlidingWindow.new }

        @metadata = Hash.new { |h, k| h[k] = Metadata.new }
        super # MonitorMixin
      end

      # @return [Array<String>]
      def names
        synchronize { @metadata.keys }
      end

      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::Metadata]
      def get_metadata(config)
        light_name = config.name

        synchronize do
          current_time = self.current_time
          recovery_window_start = (current_time - config.cool_off_time)
          recovered_at = @metadata[light_name].recovered_at
          window_start = if config.window_size
            [recovered_at, (current_time - config.window_size)].compact.max
          else
            current_time
          end

          @metadata[light_name].with(
            current_time:,
            errors: @errors[config.name].sum_in_window(window_start),
            successes: @successes[config.name].sum_in_window(window_start),
            recovery_probe_errors: @recovery_probe_errors[config.name].sum_in_window(recovery_window_start),
            recovery_probe_successes: @recovery_probe_successes[config.name].sum_in_window(recovery_window_start)
          )
        end
      end

      # @param config [Stoplight::Light::Config]
      # @param failure [Stoplight::Failure]
      # @return [Stoplight::Metadata]
      def record_failure(config, failure)
        current_time = self.current_time
        light_name = config.name

        synchronize do
          @errors[light_name].increment if config.window_size

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_error_at.nil? || current_time > metadata.last_error_at
            metadata.with(
              last_error_at: current_time,
              last_error: failure,
              consecutive_errors: metadata.consecutive_errors.succ,
              consecutive_successes: 0
            )
          else
            metadata.with(
              consecutive_errors: metadata.consecutive_errors.succ,
              consecutive_successes: 0
            )
          end
          get_metadata(config)
        end
      end

      # @param config [Stoplight::Light::Config]
      # @return [void]
      def record_success(config)
        light_name = config.name
        current_time = self.current_time

        synchronize do
          @successes[light_name].increment if config.window_size

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_success_at.nil? || current_time > metadata.last_success_at
            metadata.with(
              last_success_at: current_time,
              consecutive_errors: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          else
            metadata.with(
              consecutive_errors: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          end
        end
      end

      # @param config [Stoplight::Light::Config]
      # @param failure [Stoplight::Failure]
      # @return [Stoplight::Metadata]
      def record_recovery_probe_failure(config, failure)
        light_name = config.name
        current_time = self.current_time

        synchronize do
          @recovery_probe_errors[light_name].increment

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_error_at.nil? || current_time > metadata.last_error_at
            metadata.with(
              last_error_at: current_time,
              last_error: failure,
              consecutive_errors: metadata.consecutive_errors.succ,
              consecutive_successes: 0
            )
          else
            metadata.with(
              consecutive_errors: metadata.consecutive_errors.succ,
              consecutive_successes: 0
            )
          end
          get_metadata(config)
        end
      end

      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::Metadata]
      def record_recovery_probe_success(config)
        light_name = config.name
        current_time = self.current_time

        synchronize do
          @recovery_probe_successes[light_name].increment

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_success_at.nil? || current_time > metadata.last_success_at
            metadata.with(
              last_success_at: current_time,
              consecutive_errors: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          else
            metadata.with(
              consecutive_errors: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          end
          get_metadata(config)
        end
      end

      # @param config [Stoplight::Light::Config]
      # @param state [String]
      # @return [String]
      def set_state(config, state)
        light_name = config.name

        synchronize do
          metadata = @metadata[light_name]
          @metadata[light_name] = metadata.with(locked_state: state)
        end
        state
      end

      # @return [String]
      def inspect
        "#<#{self.class.name}>"
      end

      # Combined method that performs the state transition based on color
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
      # @return [Boolean] true if this is the first instance to detect this transition
      def transition_to_color(config, color)
        case color
        when Color::GREEN
          transition_to_green(config)
        when Color::YELLOW
          transition_to_yellow(config)
        when Color::RED
          transition_to_red(config)
        else
          raise ArgumentError, "Invalid color: #{color}"
        end
      end

      # Transitions to GREEN state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_green(config)
        light_name = config.name
        current_time = self.current_time

        synchronize do
          metadata = @metadata[light_name]
          if metadata.recovered_at
            false
          else
            @metadata[light_name] = metadata.with(
              recovered_at: current_time,
              recovery_started_at: nil,
              breached_at: nil,
              recovery_scheduled_after: nil
            )
            true
          end
        end
      end

      # Transitions to YELLOW (recovery) state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_yellow(config)
        light_name = config.name
        current_time = self.current_time

        synchronize do
          metadata = @metadata[light_name]
          if metadata.recovery_started_at.nil?
            @metadata[light_name] = metadata.with(
              recovery_started_at: current_time,
              recovery_scheduled_after: nil,
              recovered_at: nil,
              breached_at: nil
            )
            true
          else
            @metadata[light_name] = metadata.with(
              recovery_scheduled_after: nil,
              recovered_at: nil,
              breached_at: nil
            )
            false
          end
        end
      end

      # Transitions to RED state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_red(config)
        light_name = config.name
        current_time = self.current_time
        recovery_scheduled_after = current_time + config.cool_off_time

        synchronize do
          metadata = @metadata[light_name]
          if metadata.breached_at
            @metadata[light_name] = metadata.with(
              recovery_scheduled_after: recovery_scheduled_after,
              recovery_started_at: nil,
              recovered_at: nil
            )
            false
          else
            @metadata[light_name] = metadata.with(
              breached_at: current_time,
              recovery_scheduled_after: recovery_scheduled_after,
              recovery_started_at: nil,
              recovered_at: nil
            )
            true
          end
        end
      end

      private def current_time
        Time.now.utc
      end
    end
  end
end

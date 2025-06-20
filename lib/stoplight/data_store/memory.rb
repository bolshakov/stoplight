# frozen_string_literal: true

require "monitor"

module Stoplight
  module DataStore
    # @see Base
    class Memory < Base
      include MonitorMixin
      KEY_SEPARATOR = ":"

      def initialize
        @errors = Hash.new { |h, k| h[k] = [] }
        @successes = Hash.new { |h, k| h[k] = [] }

        @recovery_probe_errors = Hash.new { |h, k| h[k] = [] }
        @recovery_probe_successes = Hash.new { |h, k| h[k] = [] }

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
        window_end = Time.now
        recovery_window = (window_end - config.cool_off_time + 1)..window_end

        synchronize do
          recovered_at = @metadata[light_name].recovered_at
          window = if config.window_size
            window_start = [recovered_at, (window_end - config.window_size + 1)].compact.max
            (window_start..window_end)
          else
            (..window_end)
          end

          errors = @errors[config.name].count do |request_time|
            window.cover?(request_time)
          end

          successes = @successes[config.name].count do |request_time|
            window.cover?(request_time)
          end

          recovery_probe_errors = @recovery_probe_errors[config.name].count do |request_time|
            recovery_window.cover?(request_time)
          end
          recovery_probe_successes = @recovery_probe_successes[config.name].count do |request_time|
            recovery_window.cover?(request_time)
          end

          @metadata[light_name].with(
            errors:,
            successes:,
            recovery_probe_errors:,
            recovery_probe_successes:
          )
        end
      end

      # @param metrics [<Time>]
      # @param window_size [Numeric, nil]
      # @return [void]
      def cleanup(metrics, window_size:)
        min_age = Time.now - [window_size&.*(3), METRICS_RETENTION_TIME].compact.min

        metrics.reject! { _1 < min_age }
      end

      # @param config [Stoplight::Light::Config]
      # @param failure [Stoplight::Failure]
      # @return [Stoplight::Metadata]
      def record_failure(config, failure)
        light_name = config.name

        synchronize do
          @errors[light_name].unshift(failure.time) if config.window_size

          cleanup(@errors[light_name], window_size: config.window_size)

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_error_at.nil? || failure.time > metadata.last_error_at
            metadata.with(
              last_error_at: failure.time,
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
      # @param request_id [String]
      # @param request_time [Time]
      # @return [void]
      def record_success(config, request_time: Time.now, request_id: SecureRandom.hex(12))
        light_name = config.name

        synchronize do
          @successes[light_name].unshift(request_time) if config.window_size
          cleanup(@successes[light_name], window_size: config.window_size)

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_success_at.nil? || request_time > metadata.last_success_at
            metadata.with(
              last_success_at: request_time,
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

        synchronize do
          @recovery_probe_errors[light_name].unshift(failure.time)
          cleanup(@recovery_probe_errors[light_name], window_size: config.cool_off_time)

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_error_at.nil? || failure.time > metadata.last_error_at
            metadata.with(
              last_error_at: failure.time,
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
      # @param request_id [String]
      # @param request_time [Time]
      # @return [Stoplight::Metadata]
      def record_recovery_probe_success(config, request_time: Time.now, request_id: SecureRandom.hex(12))
        light_name = config.name

        synchronize do
          @recovery_probe_successes[light_name].unshift(request_time)
          cleanup(@recovery_probe_successes[light_name], window_size: config.cool_off_time)

          metadata = @metadata[light_name]
          recovery_started_at = metadata.recovery_started_at || request_time
          @metadata[light_name] = if metadata.last_success_at.nil? || request_time > metadata.last_success_at
            metadata.with(
              last_success_at: request_time,
              recovery_started_at:,
              consecutive_errors: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          else
            metadata.with(
              recovery_started_at:,
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

      # Combined method that performs the state transition based on color
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
      # @param current_time [Time]
      # @return [Boolean] true if this is the first instance to detect this transition
      def transition_to_color(config, color, current_time: Time.now)
        case color
        when Color::GREEN
          transition_to_green(config)
        when Color::YELLOW
          transition_to_yellow(config, current_time:)
        when Color::RED
          transition_to_red(config, current_time:)
        else
          raise ArgumentError, "Invalid color: #{color}"
        end
      end

      # Transitions to GREEN state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_green(config, current_time: Time.now)
        light_name = config.name

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
      # @param current_time [Time]
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_yellow(config, current_time: Time.now)
        light_name = config.name

        synchronize do
          metadata = @metadata[light_name]
          if metadata.recovery_started_at
            false
          else
            @metadata[light_name] = metadata.with(
              recovery_started_at: current_time,
              recovery_scheduled_after: nil,
              recovered_at: nil,
              breached_at: nil
            )
            true
          end
        end
      end

      # Transitions to RED state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param current_time [Time]
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_red(config, current_time: Time.now)
        light_name = config.name
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
    end
  end
end

# frozen_string_literal: true

require "monitor"

module Stoplight
  module DataStore
    # @see Base
    # TODO: Add a way to limit the number of failures stored in memory
    class Memory < Base
      include MonitorMixin
      KEY_SEPARATOR = ":"

      def initialize
        @failures = Hash.new { |h, k| h[k] = [] }
        @successes = Hash.new { |h, k| h[k] = [] }

        @recovery_probe_failures = Hash.new { |h, k| h[k] = [] }
        @recovery_probe_successes = Hash.new { |h, k| h[k] = [] }

        @metadata = Hash.new { |h, k| h[k] = Metadata.empty }
        super # MonitorMixin
      end

      def names
        synchronize { @metadata.keys }
      end

      def get_metadata(config)
        light_name = config.name
        window_end = Time.now
        window_start = window_end - config.window_size.to_i
        recovery_window_start = window_end - config.cool_off_time.to_i

        synchronize do
          failures = @failures[config.name].count do |failure|
            failure.time > window_start && failure.time < window_end
          end

          successes = @successes[config.name].count do |request_time|
            request_time > window_start && request_time < window_end
          end

          recovery_probe_failures = @recovery_probe_failures[config.name].count do |failure|
            failure.time > recovery_window_start && failure.time < window_end
          end
          recovery_probe_successes = @recovery_probe_successes[config.name].count do |request_time|
            request_time > recovery_window_start && request_time < window_end
          end

          @metadata[light_name].with(
            window_end:,
            window_size: config.window_size,
            failures:,
            successes:,
            recovery_probe_failures:,
            recovery_probe_successes:
          )
        end
      end

      def record_failure(config, failure)
        light_name = config.name

        synchronize do
          # Keep at most +config.threshold+ number of errors
          @failures[light_name].unshift(failure)

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_failure_at.nil? || failure.time > metadata.last_failure_at
            metadata.with(
              last_failure_at: failure.time,
              last_failure: failure,
              consecutive_failures: metadata.consecutive_failures.succ,
              consecutive_successes: 0
            )
          else
            metadata.with(
              consecutive_failures: metadata.consecutive_failures.succ,
              consecutive_successes: 0
            )
          end
        end
      end

      def record_success(config, request_time: Time.now, request_id: SecureRandom.hex(12))
        light_name = config.name

        synchronize do
          @successes[light_name].unshift(request_time)
          metadata = @metadata[light_name]

          @metadata[light_name] = if metadata.last_success_at.nil? || request_time > metadata.last_success_at
            metadata.with(
              last_success_at: request_time,
              consecutive_failures: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          else
            metadata.with(
              consecutive_failures: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          end
        end
      end

      def record_recovery_probe_failure(config, failure)
        light_name = config.name

        synchronize do
          # Keep at most +config.threshold+ number of errors
          @recovery_probe_failures[light_name].unshift(failure)

          metadata = @metadata[light_name]
          @metadata[light_name] = if metadata.last_failure_at.nil? || failure.time > metadata.last_failure_at
            metadata.with(
              last_failure_at: failure.time,
              last_failure: failure,
              consecutive_failures: metadata.consecutive_failures.succ,
              consecutive_successes: 0
            )
          else
            metadata.with(
              consecutive_failures: metadata.consecutive_failures.succ,
              consecutive_successes: 0
            )
          end
        end
      end

      def record_recovery_probe_success(config, request_time: Time.now, request_id: SecureRandom.hex(12))
        light_name = config.name

        synchronize do
          @recovery_probe_successes[light_name].unshift(request_time)
          metadata = @metadata[light_name]

          @metadata[light_name] = if metadata.last_success_at.nil? || request_time > metadata.last_success_at
            metadata.with(
              last_success_at: request_time,
              consecutive_failures: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          else
            metadata.with(
              consecutive_failures: 0,
              consecutive_successes: metadata.consecutive_successes.succ
            )
          end
        end
      end

      def get_state(config)
        light_name = config.name

        metadata = synchronize do
          @metadata[light_name]
        end

        metadata.locked_state || State::UNLOCKED
      end

      def set_state(config, state)
        light_name = config.name

        synchronize do
          metadata = @metadata[light_name]
          @metadata[light_name] = metadata.with(locked_state: state)
        end
        state
      end

      def clear_state(config)
        light_name = config.name

        synchronize do
          metadata = @metadata[light_name]
          @metadata[light_name] = metadata.with(locked_state: nil)
          metadata.locked_state || State::UNLOCKED
        end
      end

      # Combined method that performs the state transition based on color
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param color [String] The color to transition to ("GREEN", "YELLOW", or "RED")
      # @param current_ts [Integer] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      def transition_to_color(config, color, current_ts: Time.now.to_i)
        case color
        when Color::GREEN
          transition_to_green(config)
        when Color::YELLOW
          transition_to_yellow(config, current_ts:)
        when Color::RED
          transition_to_red(config, current_ts:)
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

        synchronize do
          metadata = @metadata[light_name]
          @metadata[light_name] = metadata.with(recovery_started_at: nil, last_breach_at: nil)

          if metadata.recovery_started_at || metadata.last_breach_at
            true
          else
            false
          end
        end
      end

      # Transitions to YELLOW (recovery) state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param current_ts [Integer] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_yellow(config, current_ts: Time.now.to_i)
        light_name = config.name

        synchronize do
          metadata = @metadata[light_name]
          if metadata.recovery_started_at
            false
          else
            @metadata[light_name] = metadata.with(
              recovery_started_at: current_ts,
              recovery_scheduled_after: nil,
              last_breach_at: nil
            )
            true
          end
        end
      end

      # Transitions to RED state and ensures only one notification
      #
      # @param config [Stoplight::Light::Config] The light configuration
      # @param current_ts [Integer] Current timestamp
      # @return [Boolean] true if this is the first instance to detect this transition
      private def transition_to_red(config, current_ts: Time.now.to_i)
        light_name = config.name
        recovery_scheduled_after_ts = current_ts + config.cool_off_time

        synchronize do
          metadata = @metadata[light_name]
          if metadata.last_breach_at
            false
          else
            @metadata[light_name] = metadata.with(
              last_breach_at: current_ts,
              recovery_scheduled_after: recovery_scheduled_after_ts,
              recovery_started_at: nil
            )
            true
          end
        end
      end
    end
  end
end

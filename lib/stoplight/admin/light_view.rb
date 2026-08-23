# frozen_string_literal: true

require "securerandom"

module Stoplight
  class Admin
    class LightView
      COLORS = [
        Stoplight::Color::GREEN,
        Stoplight::Color::YELLOW,
        Stoplight::Color::RED
      ].freeze

      attr_reader :id
      attr_reader :latest_failure
      attr_reader :color
      attr_reader :name
      attr_reader :state
      attr_reader :failures
      attr_reader :failure_count

      def initialize(
        config:,
        id:,
        color:,
        state:,
        failures:,
        state_snapshot:,
        recovery_metrics_snapshot:,
        failure_count: nil
      )
        @id = id
        @config = config
        @name = config.name
        @color = color
        @state = state
        @failures = failures
        @failure_count = failure_count
        @latest_failure = @failures.first
        @state_snapshot = state_snapshot
        @recovery_metrics_snapshot = recovery_metrics_snapshot
      end

      def locked?
        !unlocked?
      end

      def unlocked?
        @state == Stoplight::State::UNLOCKED
      end

      # @return [Hash]
      def as_json
        {
          id: @id,
          name: @name,
          color: @color,
          failures: @failures,
          locked: locked?
        }
      end

      # @return [Array]
      def default_sort_key
        [-COLORS.index(@color).to_i, @name]
      end

      def last_check = @latest_failure&.time # TODO: take into account positive checks as well

      private def duration_in_words(seconds)
        minutes = seconds / 60
        seconds %= 60
        hours = minutes / 60
        minutes %= 60
        parts = [] #: Array[String]
        parts << "#{hours} #{(hours == 1) ? "hour" : "hours"}" if hours > 0
        parts << "#{minutes} #{(minutes == 1) ? "minute" : "minutes"}" if minutes > 0
        parts << "#{seconds} #{(seconds == 1) ? "second" : "seconds"}" if seconds > 0
        parts.join(", ")
      end

      # @return [String]
      def description_title
        case @color
        when Stoplight::Color::RED
          if locked? && @failures.empty?
            "Locked Open"
          else
            "Last Error"
          end
        when Stoplight::Color::YELLOW
          "Testing Recovery"
        when Stoplight::Color::GREEN
          if locked?
            "Forced Healthy"
          else
            "Healthy"
          end
        else
          raise T.absurd
        end
      end

      # @return [String]
      def description_message
        case @color
        when Stoplight::Color::RED
          if (latest_failure = @latest_failure)
            "#{latest_failure.error_class}: #{latest_failure.error_message}"
          elsif locked?
            "Circuit manually locked open"
          else
            "Not available"
          end
        when Stoplight::Color::YELLOW
          if (latest_failure = @latest_failure)
            "#{latest_failure.error_class}: #{latest_failure.error_message}"
          else
            "Not available"
          end
        when Stoplight::Color::GREEN
          if locked?
            "Circuit manually locked closed"
          else
            "No recent errors"
          end
        else
          raise T.absurd
        end
      end

      # @return [String]
      def description_comment
        case @color
        when Stoplight::Color::RED
          if locked?
            "Override active - all requests blocked"
          elsif (recovery_at = @state_snapshot.recovery_scheduled_after)
            recovery_in = [0, (recovery_at - Time.now.utc).to_i].max
            if recovery_in > 0
              "Will attempt recovery in #{duration_in_words(recovery_in)}"
            else
              "Recovery started: awaiting test traffic"
            end
          else
            "Recovery started: awaiting test traffic"
          end
        when Stoplight::Color::YELLOW
          recovery_metrics_snapshot = T.must(@recovery_metrics_snapshot)
          if recovery_metrics_snapshot.consecutive_successes.zero?
            "Recovery started: awaiting test traffic"
          else
            "Allowing limited test traffic (#{recovery_metrics_snapshot.consecutive_successes} of #{@config.recovery_threshold} requests)"
          end
        when Stoplight::Color::GREEN
          if locked?
            "Override active - all requests processed"
          else
            "Operating normally"
          end
        else
          raise T.absurd
        end
      end
    end
  end
end

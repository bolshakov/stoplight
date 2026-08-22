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

      def initialize(config:, id:, color:, state:, failures:, recovery_metrics_snapshot:, failure_count: nil)
        @id = id
        @config = config
        @name = config.name
        @color = color
        @state = state
        @failures = failures
        @failure_count = failure_count
        @latest_failure = @failures.first
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

      # @return [String, nil]
      # TODO: is this method still in use?
      def last_check_in_words
        last_error_time = @latest_failure&.time
        return unless last_error_time

        time_difference = (Time.now.utc - last_error_time).to_i
        if time_difference < 1
          "just now"
        elsif time_difference < 60
          "#{time_difference.to_i}s ago"
        elsif time_difference < 3600
          "#{(time_difference / 60).to_i}m ago"
        elsif time_difference < 86400
          "#{(time_difference / 3600).to_i}h ago"
        else
          "#{(time_difference / 86400).to_i}d ago"
        end
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
          else
            "Will attempt recovery after cooling period"
          end
        when Stoplight::Color::YELLOW
          recovery_metrics_snapshot = T.must(@recovery_metrics_snapshot)
          "Allowing limited test traffic (#{recovery_metrics_snapshot.consecutive_successes} of #{@config.recovery_threshold} requests)"
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

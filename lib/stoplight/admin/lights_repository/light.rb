# frozen_string_literal: true

require "securerandom"

module Stoplight
  class Admin
    class LightsRepository
      class Light
        COLORS = [
          GREEN = Stoplight::Color::GREEN,
          YELLOW = Stoplight::Color::YELLOW,
          RED = Stoplight::Color::RED
        ].freeze

        # @!attribute id
        #   @return [String]
        attr_reader :id

        # @!attribute name
        #   @return [String]
        attr_reader :name

        # @!attribute color
        #   @return [String]
        attr_reader :color

        # @!attribute state
        #   @return [String]
        attr_reader :state

        # @!attribute failures
        #   @return [<Stoplight::Failure>]
        attr_reader :failures

        # @!attribute failure_count
        #   @return [Integer]
        attr_reader :failure_count

        # @param name [String]
        # @param color [String]
        # @param state [String]
        # @param failures [<Stoplight::Failure>]
        # @param failure_count [Integer, nil]
        def initialize(name:, color:, state:, failures:, failure_count: nil)
          @id = SecureRandom.uuid
          @name = name
          @color = color
          @state = state
          @failures = failures
          @failure_count = failure_count
        end

        def latest_failure
          failures.first
        end

        # @return [Boolean]
        def locked?
          !unlocked?
        end

        # @return [Boolean]
        def unlocked?
          state == Stoplight::State::UNLOCKED
        end

        # @return [Hash]
        def as_json
          {
            name: name,
            color: color,
            failures: failures,
            locked: locked?
          }
        end

        # @return [Array]
        def default_sort_key
          [-COLORS.index(color), name]
        end

        def last_check = latest_failure&.time # TODO: take into account positive checks as well

        # @return [String, nil]
        def last_check_in_words
          last_error_time = latest_failure&.time
          return unless last_error_time

          time_difference = Time.now.utc - last_error_time
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
          case color
          when RED
            if locked? && failures.empty?
              "Locked Open"
            else
              "Last Error"
            end
          when Stoplight::Color::YELLOW
            "Testing Recovery"
          when GREEN
            if locked?
              "Forced Healthy"
            else
              "Healthy"
            end
          end
        end

        # @return [String]
        def description_message
          case color
          when RED
            if latest_failure
              "#{latest_failure.error_class}: #{latest_failure.error_message}"
            elsif locked?
              "Circuit manually locked open"
            else
              "Not available"
            end
          when Stoplight::Color::YELLOW
            if latest_failure
              "#{latest_failure.error_class}: #{latest_failure.error_message}"
            else
              "Not available"
            end
          when GREEN
            if locked?
              "Circuit manually locked closed"
            else
              "No recent errors"
            end
          end
        end

        # @return [String]
        def description_comment
          case color
          when RED
            if locked?
              "Override active - all requests blocked"
            else
              "Will attempt recovery after cooling period"
            end
          when YELLOW
            "Allowing limited test traffic (0 of 1 requests)"
          when GREEN
            if locked?
              "Override active - all requests processed"
            else
              "Operating normally"
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Admin
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

        # @param name [String]
        # @param color [String]
        # @param state [String]
        # @param failures [<Stoplight::Failure>]
        def initialize(name:, color:, state:, failures:)
          @id = SecureRandom.uuid
          @name = name
          @color = color
          @state = state
          @failures = failures
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

        # @return [String, nil]
        def last_check_in_words
          last_failure_time = latest_failure&.time
          return unless last_failure_time

          time_difference = Time.now - last_failure_time
          if time_difference < 60
            "#{time_difference.to_i}s ago"
          elsif time_difference < 3600
            "#{(time_difference / 60).to_i}m ago"
          else
            "#{(time_difference / 3600).to_i}h ago"
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
          when YELLOW
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
            if locked? && failures.empty?
              "Circuit manually locked open"
            else
              "#{latest_failure.error_class}: #{latest_failure.error_message}"
            end
          when YELLOW
            "#{latest_failure.error_class}: #{latest_failure.error_message}"
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

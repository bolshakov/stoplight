# frozen_string_literal: true

module Stoplight
  module Domain
    # Request metrics over a given window.
    #
    # @!attribute successes
    #   A number of successes withing requested window. Zero for non-windowed metrics
    #   @return [Integer]
    #
    # @!attribute errors
    #   A number of errors withing requested window. Zero for non-windowed metrics
    #   @return [Integer]
    #
    # @!attribute total_consecutive_errors
    #   A total number of consecutive errors
    #   @return [Integer]
    #
    # @!attribute total_consecutive_successes
    #   A total number of consecutive successes
    #   @return [Integer]
    #
    # @!attribute last_error
    #   @return [Stoplight::Domain::Failure, nil]
    #
    # @!attribute last_success_at
    #   @return [Time, nil]
    #
    # @api private
    Metrics = Data.define(
      :successes,
      :errors,
      :total_consecutive_errors,
      :total_consecutive_successes,
      :last_error,
      :last_success_at
    ) do
      # A number of consecutive errors withing requested window
      #
      # @return [Integer]
      def consecutive_errors
        if errors # we effectively check if this is windowed metrics
          [total_consecutive_errors, errors].min
        else
          total_consecutive_errors
        end
      end

      # A number of consecutive successes withing requested window
      #
      def consecutive_successes
        if successes # we effectively check if this is windowed metrics
          [total_consecutive_successes, successes].min
        else
          total_consecutive_successes
        end
      end

      # Calculates the error rate based on the number of successes and errors.
      #
      # @return [Float]
      def error_rate
        return unless requests # we effectively check if this is windowed metrics

        if (successes + errors).zero?
          0.0
        else
          errors.fdiv(successes + errors)
        end
      end

      # @return [Integer]
      def requests
        if successes && errors # we effectively check if this is windowed metrics
          successes + errors
        end
      end

      # @return [Time, nil]
      def last_error_at
        last_error&.time
      end
    end
  end
end

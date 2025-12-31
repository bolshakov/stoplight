# frozen_string_literal: true

module Stoplight
  module Domain
    # Request metrics over a given window.
    #
    # @api private
    MetricsSnapshot = Data.define(
      :successes,
      :errors,
      :consecutive_errors,
      :consecutive_successes,
      :last_error,
      :last_success_at
    )

    class MetricsSnapshot
      # @!attribute successes
      #   A number of successes withing requested window. Zero for non-windowed metrics
      #   @return [Integer]
      #
      # @!attribute errors
      #   A number of errors withing requested window. Zero for non-windowed metrics
      #   @return [Integer]
      #
      # @!attribute consecutive_errors
      #   A number of consecutive errors
      #   @return [Integer]
      #
      # @!attribute consecutive_successes
      #   A number of consecutive successes
      #   @return [Integer]
      #
      # @!attribute last_error
      #   @return [Stoplight::Domain::Failure, nil]
      #
      # @!attribute last_success_at
      #   @return [Time, nil]

      # Calculates the error rate based on the number of successes and errors.
      #
      # @return [Float]
      def error_rate
        return unless requests # we effectively check if this is windowed metrics

        if (successes! + errors!).zero?
          0.0
        else
          errors!.fdiv(successes! + errors!)
        end
      end

      # @return [Integer]
      def requests
        if successes && errors # we effectively check if this is windowed metrics
          successes! + errors!
        end
      end

      # @return [Time, nil]
      def last_error_at
        last_error&.time
      end

      def successes!
        successes or raise TypeError, "success must not be nil"
      end

      def errors!
        errors or raise TypeError, "errors must not be nil"
      end
    end
  end
end

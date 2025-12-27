# frozen_string_literal: true

require "json"
require "time"

module Stoplight
  module Domain
    # @api private
    class Failure
      # @return [String]
      # @dynamic error_class
      attr_reader :error_class
      # @return [String]
      # @dynamic error_message
      attr_reader :error_message
      # @return [Time]
      # @dynamic time
      attr_reader :time

      # @param error [Exception]
      # @return (see #initialize)
      def self.from_error(error, time:)
        new(error.class.name, error.message, time)
      end

      # @param error_class [String]
      # @param error_message [String]
      # @param time [Time]
      def initialize(error_class, error_message, time)
        @error_class = error_class
        @error_message = error_message
        @time = time
      end

      alias_method :occurred_at, :time

      # @param other [Failure]
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class) &&
          error_class == other.error_class &&
          error_message == other.error_message &&
          time == other.time
      end
    end
  end
end

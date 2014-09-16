# coding: utf-8

module Stoplight
  module Error
    # @return [Class]
    Base = Class.new(StandardError)

    # @return [Class]
    RedLight = Class.new(Base)

    # @return [Class]
    InvalidColor = Class.new(Base)

    # @return [Class]
    InvalidFailure = Class.new(Base)

    # @return [Class]
    InvalidState = Class.new(Base)

    # @return [Class]
    InvalidThreshold = Class.new(Base)

    # @return [Class]
    InvalidTimeout = Class.new(Base)

    # @return [Class]
    class BadDataStore < Base
      # @return [Exception]
      attr_reader :cause

      # @param cause [Exception]
      def initialize(cause)
        super(cause.message)
        @cause = cause
      end
    end
  end
end

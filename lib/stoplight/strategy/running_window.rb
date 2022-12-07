# frozen_string_literal: true

require 'forwardable'

module Stoplight
  module Strategy
    # Running Window strategy takes into account only errors that happened
    # within last last +window+ seconds
    #
    class RunningWindow < Base
      # @!attribute window
      #   @return [Integer]
      attr_reader :window

      # @param data_store [Stoplight::DataStore::Base]
      # @param window [Integer]
      def initialize(data_store, window:)
        super(data_store)
        @window = window
      end

      def clear_failures(light)
        data_store.clear_failures(light, window: window)
      end

      def get_all(light)
        data_store.get_all(light, window: window)
      end

      def get_failures(light)
        data_store.get_failures(light, window: window)
      end

      def record_failure(light, failure)
        data_store.record_failure(light, failure, window: window)
      end
    end
  end
end

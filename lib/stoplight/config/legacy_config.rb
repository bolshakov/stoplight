# frozen_string_literal: true

module Stoplight
  module Config
    # A configuration class that supports legacy configuration options.
    #
    # @api private
    class LegacyConfig
      extend Forwardable

      # @param data_store [Stoplight::DataStore::Base, nil]
      # @param error_notifier [#call, nil]
      # @param notifiers [Array<Stoplight::Notifier::Base>, nil]
      def initialize(data_store: nil, error_notifier: nil, notifiers: nil)
        @data_store = data_store
        @error_notifier = error_notifier
        @notifiers = notifiers
      end

      private attr_reader :data_store
      private attr_reader :error_notifier
      private attr_reader :notifiers

      # @return [Hash]
      def to_h
        {
          data_store:,
          error_notifier:,
          notifiers:
        }.compact
      end

      def_delegator :to_h, :any?
    end
  end
end

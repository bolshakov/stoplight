# frozen_string_literal: true

module Stoplight
  module Config
    class LegacyConfig
      extend Forwardable

      attr_accessor :data_store
      attr_accessor :error_notifier
      attr_accessor :notifiers

      # @return [Hash]
      def to_h
        {
          data_store:,
          error_notifier:,
          notifiers:
        }.compact
      end

      def_delegator :to_h, :empty?
    end
  end
end

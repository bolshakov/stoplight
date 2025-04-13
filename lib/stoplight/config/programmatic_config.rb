# frozen_string_literal: true

require "forwardable"

module Stoplight
  module Config
    class ProgrammaticConfig
      extend Forwardable

      attr_writer :cool_off_time
      attr_writer :data_store
      attr_writer :error_notifier
      attr_writer :notifiers
      attr_writer :threshold
      attr_writer :window_size
      attr_writer :tracked_errors
      attr_writer :skipped_errors

      # @return [Hash]
      def to_h
        {
          cool_off_time: @cool_off_time,
          data_store: @data_store,
          error_notifier: @error_notifier,
          notifiers: @notifiers,
          threshold: @threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors
        }.compact
      end

      def_delegator :to_h, :empty?
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Wiring
    class MemoryBackend < DataStoreBackend
      def initialize(clock:, config:)
        @clock = clock
        @config = config
      end

      def state_store
        @state_store ||= Infrastructure::Memory::Storage::State.new(
          clock: @clock,
          cool_off_time: @config.cool_off_time
        )
      end

      def recovery_lock_store
        @recovery_lock_store ||= Infrastructure::Memory::Storage::RecoveryLock.new
      end

      def recovery_metrics_store
        @recovery_metrics_store ||= Infrastructure::Memory::Storage::RecoveryMetrics.new(
          clock: @clock
        )
      end

      def windowed_metrics_store
        @windowed_metrics_store ||= Infrastructure::Memory::Storage::WindowMetrics.new(
          config: @config, # TODO: inject window_size instead
          clock: @clock
        )
      end

      def unbounded_metrics_store
        @unbounded_metrics_store ||= Infrastructure::Memory::Storage::UnboundedMetrics.new(
          clock: @clock
        )
      end
    end
  end
end

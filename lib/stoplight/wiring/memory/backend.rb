# frozen_string_literal: true

module Stoplight
  module Wiring
    module Memory
      # In-memory storage backend for single-process deployments.
      #
      # All storage components use thread-safe in-memory data structures.
      # State is not shared across processes and is lost on restart.
      #
      # Memory backend is also used as the fallback layer for Redis backend
      # when Redis is unavailable.
      #
      # @example
      #   backend = Memory::Backend.new(clock: SystemClock.new, config:)
      #   backend.state_store #=> Memory::Storage::State
      #
      # @api private
      class Backend < DataStoreBackend
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
            window_size: T.must(@config.window_size),
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
end

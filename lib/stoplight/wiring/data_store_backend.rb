# frozen_string_literal: true

module Stoplight
  module Wiring
    # Abstract base class defining the storage backend interface.
    #
    # A backend encapsulates all storage construction for a specific data store type
    # (Memory or Redis). Backends handle infrastructure concerns like connection
    # management and failover wrapping, exposing a uniform interface to StorageSetBuilder.
    #
    # Each method returns a memoized storage instance. Backends are designed to be
    # instantiated once per Light and reused.
    #
    # @abstract Subclass and implement all methods
    # @see Memory::Backend
    # @see Redis::Backend
    # @api private
    class DataStoreBackend
      def state_store = raise ArgumentError
      def recovery_lock_store = raise ArgumentError
      def recovery_metrics_store = raise ArgumentError
      def windowed_metrics_store = raise ArgumentError
      def unbounded_metrics_store = raise ArgumentError
    end
  end
end

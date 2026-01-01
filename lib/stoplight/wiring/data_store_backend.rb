# frozen_string_literal: true

module Stoplight
  module Wiring
    class DataStoreBackend
      def state_store = raise ArgumentError
      def recovery_lock_store = raise ArgumentError
      def recovery_metrics_store = raise ArgumentError
      def windowed_metrics_store = raise ArgumentError
      def unbounded_metrics_store = raise ArgumentError
    end
  end
end

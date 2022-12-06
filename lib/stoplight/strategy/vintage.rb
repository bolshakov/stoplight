# frozen_string_literal: true

require 'forwardable'

module Stoplight
  module Strategy
    # Vintage strategy is the old good strategy
    # that Stoplight have been using since the beginning.
    # It does not take into account the time when an error
    # happens.
    #
    class Vintage < Base
      extend Forwardable

      attr_reader :data_store

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store)
        @data_store = data_store
      end

      def_delegator :data_store, :clear_failures
      def_delegator :data_store, :get_all
      def_delegator :data_store, :get_failures
      def_delegator :data_store, :record_failure
      def_delegator :data_store, :set_state
      def_delegator :data_store, :with_notification_lock
    end
  end
end

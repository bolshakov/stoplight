# frozen_string_literal: true

require 'forwardable'

module Stoplight
  module Strategy
    # @abstract
    class Base
      extend Forwardable

      # @!attribute data_store
      #   @return [Stoplight::DataStore::Base]
      attr_reader :data_store
      # private :data_store

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store)
        @data_store = data_store
      end

      # @param _light [Light]
      # @return [Array(Array<Failure>, String)]
      def get_all(_light)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @return [Array<Failure>]
      def get_failures(_light)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @param _failure [Failure]
      # @return [Fixnum]
      def record_failure(_light, _failure)
        raise NotImplementedError
      end

      # @param _light [Light]
      # @return [Array<Failure>]
      def clear_failures(_light)
        raise NotImplementedError
      end

      def_delegator :data_store, :clear_state
      def_delegator :data_store, :get_state
      def_delegator :data_store, :names
      def_delegator :data_store, :set_state
      def_delegator :data_store, :with_notification_lock
    end
  end
end

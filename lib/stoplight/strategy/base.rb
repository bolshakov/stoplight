# frozen_string_literal: true

module Stoplight
  module Strategy
    # @abstract
    class Base
      # @!attribute data_store
      #   @return [Stoplight::DataStore::Base]
      attr_reader :data_store
      private :data_store

      # @param data_store [Stoplight::DataStore::Base]
      def initialize(data_store)
        @data_store = data_store
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      # @api private
      # @abstract
      class Base
        # @!attribute [r] data_store
        #   @return [Stoplight::DataStore::Base] The data store associated with the light.
        protected attr_reader :data_store

        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        protected attr_reader :notifiers

        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        protected attr_reader :config

        def ==(other)
          other.is_a?(self.class) &&
            config == other.config &&
            data_store == other.data_store &&
            notifiers == other.notifiers
        end
      end
    end
  end
end

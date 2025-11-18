# frozen_string_literal: true

module Stoplight
  module Wiring
    module DataStore
      # @abstract
      class Base
        # @param container [Stoplight::Infrastructure::DependencyInjection::Container]
        # @return [Stoplight::Domain::DataStore]
        # @api private
        def create(container)
          raise NotImplementedError
        end
      end
    end
  end
end

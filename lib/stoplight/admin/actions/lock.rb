# frozen_string_literal: true

module Stoplight
  module Admin
    module Actions
      # This action locks light
      class Lock < Action
        # @param params [Hash] query parameters
        # @return [void]
        def call(params)
          light_names(params).each do |name|
            lights_repository.lock(name)
          end
        end

        private def light_names(params)
          Array(params[:names])
            .map { |name| CGI.unescape(name) }
        end
      end
    end
  end
end

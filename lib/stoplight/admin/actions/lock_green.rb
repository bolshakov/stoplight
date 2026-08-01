# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks light with the specific name green
      class LockGreen < Action
        # @param params [Hash] query parameters
        # @return [void]
        def call(params)
          Array(params[:ids]).each do |name|
            @lights_repository.lock(name, Color::GREEN)
          end
        end
      end
    end
  end
end

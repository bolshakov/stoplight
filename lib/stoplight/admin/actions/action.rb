# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # @abstract
      class Action
        def initialize(lights_repository:)
          @lights_repository = lights_repository
        end

        def halt(*response)
          response = response.first if response.length == 1
          throw :halt, response
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # @abstract
      class Action
        def initialize(lights_repository:)
          @lights_repository = lights_repository
        end
      end
    end
  end
end

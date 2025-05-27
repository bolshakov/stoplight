# frozen_string_literal: true

module Stoplight
  module Admin
    module Actions
      # This action locks all lights green
      class LockAllGreen < Action
        # @return [void]
        def call(*)
          lights_repository
            .with_color(RED, YELLOW)
            .map(&:name)
            .each { |name| lights_repository.lock(name, GREEN) }
        end
      end
    end
  end
end

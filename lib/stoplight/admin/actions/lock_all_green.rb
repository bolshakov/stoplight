# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks all lights green
      class LockAllGreen < Action
        # @return [void]
        def call(*)
          @lights_repository
            .with_color(Color::RED, Color::YELLOW)
            .each { |light| @lights_repository.lock(light.id, Color::GREEN) }
        end
      end
    end
  end
end

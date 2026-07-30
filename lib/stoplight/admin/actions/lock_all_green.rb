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
            .map(&:name)
            .each { |name| @lights_repository.lock(name, Color::GREEN) }
        end
      end
    end
  end
end

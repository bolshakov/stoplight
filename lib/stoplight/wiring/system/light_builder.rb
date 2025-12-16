# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightBuilder < Wiring::LightBuilder
        private attr_reader :system
        private attr_reader :failover_system

        def initialize(system, settings)
          @system = system
          @failover_system = Stoplight.__stoplight__system("failover-#{system.name}")

          super(settings)
        end

        def key_space = Infrastructure::Storage::Redis::KeySpace.build(
          system_name: system.name,
          light_name: config.name
        )
      end
    end
  end
end

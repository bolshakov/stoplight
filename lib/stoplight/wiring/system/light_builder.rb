# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightBuilder < Wiring::LightBuilder
        private attr_reader :system

        def initialize(system, settings)
          @system = system

          super(settings)
        end

        def key_space = Infrastructure::Storage::Redis::KeySpace.build(
          system_name: system.name,
          light_name: config.name
        )

        private def redis = data_store_config
        private def storage_scripting = Infrastructure::Storage::Redis::Scripting.new(redis:)
        private def failover_system = @failover_system ||= Stoplight.__stoplight__system("failover-#{system.name}")
      end
    end
  end
end

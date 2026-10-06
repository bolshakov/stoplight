# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      class Dependencies
        def initialize(system:)
          @system = system
          @storage = @system.__stoplight__storage
        end

        def config_registry
          ConfigRegistry.new(
            registry: @system.__stoplight__registry,
            system_config: @system.config
          )
        end

        def light_list_action
          Actions::LightList.new(
            config_registry: config_registry,
            storage: @storage
          )
        end
      end
    end
  end
end

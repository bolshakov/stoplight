# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action locks light
      class Lock < Action
        def initialize(config_registry:, storage:)
          @config_registry = config_registry
          @storage = storage
        end

        def call(light_id:, color:)
          config = @config_registry.find_by_id(light_id)
          if config
            @storage.lock(config, color)
          else
            halt 404
          end
        end
      end
    end
  end
end

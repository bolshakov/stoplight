# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action removes a light's metadata from Redis
      class Remove < Action
        def initialize(config_registry:, storage:, registry:)
          @config_registry = config_registry
          @storage = storage
          @registry = registry
        end

        def call(light_id:)
          config = @config_registry.find_by_id(light_id)
          if config
            @storage.delete(config)
            @registry.unregister(config.id)  # TODO: move to @storage?
          else
            halt 404
          end
        end
      end
    end
  end
end

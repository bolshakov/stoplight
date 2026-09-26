# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # This action unlocks light
      class Unlock < Action
        def initialize(config_registry:, storage:)
          @config_registry = config_registry
          @storage = storage
        end

        def call(light_id:)
          config = @config_registry.find_by_id(light_id)
          if config
            @storage.unlock(config)
          else
            halt 404
          end
        end
      end
    end
  end
end

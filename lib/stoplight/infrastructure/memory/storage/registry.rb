# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        class Registry
          def ids = []
          def all_configs = []

          def register(config) = nil
          def unregister(id) = nil
          def config_for(id) = nil
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        class Registry
          def names = []

          def register(name, config:) = nil
          def unregister(name) = nil
          def config_for(name) = nil
        end
      end
    end
  end
end

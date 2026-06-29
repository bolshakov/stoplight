# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        class Registry
          def names = []

          def register(name, config:) = nil
          def unregister(name) = nil
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
        class Scripting < DataStore::Redis::Scripting
          SCRIPTS_ROOT = __dir__
          private_constant :SCRIPTS_ROOT

          class << self
            def default_scripts_root = SCRIPTS_ROOT
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
        class RecoveryMetrics < UnboundedMetrics
          def initialize(redis:, scripting:, key_space:, clock:)
            super
            @metrics_key = key_space.key(:recovery_metrics)
          end
        end
      end
    end
  end
end

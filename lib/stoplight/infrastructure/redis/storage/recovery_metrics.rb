# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        # When a circuit is RED (open), Stoplight periodically sends "recovery probes"
        # to test whether the protected service has recovered. These test requests have
        # different semantics than normal requests and their metrics are tracked separately.
        #
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

# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        # When a circuit is RED (open), Stoplight periodically sends "recovery probes"
        # to test whether the protected service has recovered. These test requests have
        # different semantics than normal requests and their metrics are tracked separately.
        #
        # @see Stoplight::Domain::Storage::Metrics
        class RecoveryMetrics < UnboundedMetrics
        end
      end
    end
  end
end

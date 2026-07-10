# frozen_string_literal: true

module Stoplight
  module Domain
    class Telemetry
      # Runtime name for the +state_transitioned+ union: a marker module included by every transition variant.
      module StateTransitioned
      end
    end
  end
end

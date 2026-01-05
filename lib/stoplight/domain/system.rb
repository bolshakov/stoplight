# frozen_string_literal: true

module Stoplight
  module Domain
    # Abstract base class defining the System contract.
    #
    # A System is a composition root that groups related circuit breakers
    # with shared configuration. Concrete implementations live in the
    # Wiring layer.
    #
    # @abstract
    class System
      def name = raise NotImplementedError

      def light(
        name,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        skipped_errors: T.undefined,
        tracked_errors: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      ) = raise NotImplementedError
    end
  end
end

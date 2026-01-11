# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Defines how the light executes when it is red.
      #
      # This strategy prevents execution of the code block and either raises an error
      # or invokes a fallback if provided.
      #
      # @api private
      class RedRunStrategy
        def initialize(name:, cool_off_time:)
          @name = name
          @cool_off_time = cool_off_time
        end

        # Executes the fallback proc when the light is in the red state.
        #
        # @param fallback A fallback proc to execute instead of the code block.
        # @param state_snapshot
        # @return The result of the fallback proc if provided.
        # @raise [Stoplight::Error::RedLight] Raises an error if no fallback is provided.
        def execute(fallback, state_snapshot:)
          if fallback
            fallback.call(nil)
          else
            raise Error::RedLight.new(
              @name,
              cool_off_time: @cool_off_time,
              retry_after: state_snapshot.recovery_scheduled_after
            )
          end
        end
      end
    end
  end
end

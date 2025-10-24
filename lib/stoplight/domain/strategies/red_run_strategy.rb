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
      class RedRunStrategy < RunStrategy
        # Executes the fallback proc when the light is in the red state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute instead of the code block.
        # @param metadata [Stoplight::Domain::Metadata] Metadata capturing the current state of the light.
        # @return [Object, nil] The result of the fallback proc if provided.
        # @raise [Stoplight::Error::RedLight] Raises an error if no fallback is provided.
        def execute(fallback, metadata:)
          if fallback
            fallback.call(nil)
          else
            raise Error::RedLight.new(
              config.name,
              cool_off_time: config.cool_off_time,
              retry_after: metadata.recovery_scheduled_after
            )
          end
        end
      end
    end
  end
end

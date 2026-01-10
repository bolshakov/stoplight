# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Defines how the light executes when it is green.
      #
      # This strategy clears failures after successful execution and handles errors
      # by either raising them or invoking a fallback if provided.
      #
      # @api private
      class GreenRunStrategy
        def initialize(config:, request_tracker:)
          @config = config
          @request_tracker = request_tracker
        end

        # Executes the provided code block when the light is in the green state.
        #
        # @param fallback A fallback proc to execute in case of an error.
        # @param state_snapshot
        # @yield The code block to execute.
        # @return The result of the code block if successful.
        # @raise re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, &code)
          # TODO: Consider implementing sampling rate to limit the memory footprint
          result = code.call
          record_success
          result
        rescue => error
          if @config.track_error?(error)
            record_error(error)

            if fallback
              fallback.call(error)
            else
              raise
            end
          else
            # User chose to not track the error, so we record it as a success
            record_success
            raise
          end
        end

        private

        attr_reader :config
        attr_reader :request_tracker

        def record_error(error)
          request_tracker.record_failure(error)
        end

        def record_success
          request_tracker.record_success
        end
      end
    end
  end
end

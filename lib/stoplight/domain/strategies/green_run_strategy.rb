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
      class GreenRunStrategy < RunStrategy
        # @!attribute [r] request_tracker
        #   @return [Stoplight::Domain::Tracker::Request]
        # @dynamic request_tracker
        protected attr_reader :request_tracker

        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        # @dynamic config
        protected attr_reader :config

        # @param config [Stoplight::Domain::Config]
        # @param request_tracker [Stoplight::Domain::Tracker::Request
        def initialize(config:, request_tracker:)
          @config = config
          @request_tracker = request_tracker
        end

        # Executes the provided code block when the light is in the green state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param state_snapshot [Stoplight::Domain::StateSnapshot]
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, &code)
          # TODO: Consider implementing sampling rate to limit the memory footprint
          result = code.call
          record_success
          result
        rescue => error
          if config.track_error?(error)
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

        private def record_error(error)
          request_tracker.record_failure(error)
        end

        private def record_success
          request_tracker.record_success
        end

        # @return [Boolean]
        def ==(other)
          super && config == other.config && request_tracker == other.request_tracker
        end
      end
    end
  end
end

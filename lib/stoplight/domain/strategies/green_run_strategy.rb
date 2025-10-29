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
        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        protected attr_reader :traffic_control

        # @!attribute [r] notifiers
        #   @return [Stoplight::Domain::StateTransitionNotifier]
        protected attr_reader :notifiers

        # @param config [Stoplight::Domain::Config]
        # @param data_store [Stoplight::Domain::DataStore]
        # @param traffic_control [Stoplight::Domain::TrafficControl::Base]
        # @param notifiers [Array<Stoplight::Domain::StateTransitionNotifier>]
        def initialize(config:, data_store:, traffic_control:, notifiers:)
          super(config:, data_store:)
          @traffic_control = traffic_control
          @notifiers = notifiers
        end

        # Executes the provided code block when the light is in the green state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param metadata [Stoplight::Domain::Metadata] Metadata capturing the current state of the light.
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, metadata:, &code)
          # TODO: Consider implementing sampling rate to limit the memory footprint
          code.call.tap { record_success }
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
          failure = Failure.from_error(error)
          metadata = data_store.record_failure(config, failure)

          if traffic_control.stop_traffic?(config, metadata) && data_store.transition_to_color(config, Color::RED)
            notifiers.each do |notifier|
              notifier.notify(config, Color::GREEN, Color::RED, error)
            end
          end
        end

        private def record_success
          data_store.record_success(config)
        end

        # @return [Boolean]
        def ==(other)
          super && traffic_control == other.traffic_control && notifiers == other.notifiers
        end
      end
    end
  end
end

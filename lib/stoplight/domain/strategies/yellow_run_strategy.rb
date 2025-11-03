# frozen_string_literal: true

module Stoplight
  module Domain
    module Strategies
      # Defines how the light executes when it is yellow.
      #
      # This strategy clears failures after successful execution and notifies
      # about color switch from Red to Green. It also handles errors by either
      # raising them or invoking a fallback if provided.
      #
      # @api private
      class YellowRunStrategy < RunStrategy
        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        protected attr_reader :config

        # @!attribute [r] data_store
        #   @return [Stoplight::DataStore::Base] The data store associated with the light.
        protected attr_reader :data_store

        # @!attribute [r] notifiers
        #   @return [Stoplight::Domain::StateTransitionNotifier]
        protected attr_reader :notifiers

        # @!attribute [r] request_tracker
        #   @return [Stoplight::Domain::RecoveryProbeRequestRecorder]
        protected attr_reader :request_tracker

        # @param config [Stoplight::Domain::Config]
        # @param data_store [Stoplight::DataStore::Base]
        # @param notifiers [Array<Stoplight::Domain::StateTransitionNotifier>]
        # @param request_tracker [Stoplight::Domain::Tracker::RecoveryProbe]
        def initialize(config:, data_store:, notifiers:, request_tracker:)
          @config = config
          @data_store = data_store
          @notifiers = notifiers
          @request_tracker = request_tracker
        end

        # Executes the provided code block when the light is in the yellow state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param metadata [Stoplight::Domain::Metadata] Metadata capturing the current state of the light.
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, metadata:, &code)
          enter_recovery_if_needed(metadata)
          # TODO: We need to employ a probabilistic approach here to avoid "thundering herd" problem
          code.call.tap { record_recovery_probe_success }
        rescue => error
          if config.track_error?(error)
            record_recovery_probe_failure(error)

            if fallback
              fallback.call(error)
            else
              raise
            end
          else
            record_recovery_probe_success
            raise
          end
        end

        private def record_recovery_probe_success
          request_tracker.record_success
        end

        private def record_recovery_probe_failure(error)
          request_tracker.record_failure(error)
        end

        # @param metadata [Stoplight::Domain::Metadata]
        # @return [void]
        private def enter_recovery_if_needed(metadata)
          return if metadata.recovery_started?

          if data_store.transition_to_color(config, Color::YELLOW)
            notifiers.each do |notifier|
              notifier.notify(config, Color::RED, Color::YELLOW, nil)
            end
          end
        end

        # @return [Boolean]
        def ==(other)
          super &&
            config == other.config &&
            notifiers == other.notifiers &&
            data_store == other.data_store &&
            request_tracker == other.request_tracker
        end
      end
    end
  end
end

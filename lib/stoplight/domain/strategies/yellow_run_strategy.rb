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

        # @!attribute [r] red_run_strategy
        #   @return [Stoplight::Domain::Strategies::RedRunStrategy]
        protected attr_reader :red_run_strategy

        # @param config [Stoplight::Domain::Config]
        # @param data_store [Stoplight::DataStore::Base]
        # @param notifiers [Array<Stoplight::Domain::StateTransitionNotifier>]
        # @param request_tracker [Stoplight::Domain::Tracker::RecoveryProbe]
        # @param red_run_strategy [Stoplight::Domain::Strategies::RedRunStrategy]
        def initialize(config:, data_store:, notifiers:, request_tracker:, red_run_strategy:)
          @config = config
          @data_store = data_store
          @notifiers = notifiers
          @request_tracker = request_tracker
          @red_run_strategy = red_run_strategy
        end

        # Executes the provided code block when the light is in the yellow state.
        #
        # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
        # @param state_snapshot [Stoplight::Domain::StateSnapshot]
        # @yield The code block to execute.
        # @return [Object] The result of the code block if successful.
        # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
        def execute(fallback, state_snapshot:, &code)
          # Everything withing this block executed exclusively:
          #   - enter recovery
          #   - execute user's code
          #   - record outcome
          #   - transition to green or red if needed
          with_recovery_lock(fallback:, state_snapshot:) do
            enter_recovery(state_snapshot)

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
        end

        def with_recovery_lock(fallback:, state_snapshot:)
          recovery_lock_token = data_store.acquire_recovery_lock(config)
          if recovery_lock_token.nil?
            return red_run_strategy.execute(fallback, state_snapshot:)
          end

          begin
            yield
          ensure
            data_store.release_recovery_lock(recovery_lock_token)
          end
        end

        private def record_recovery_probe_success
          request_tracker.record_success
        end

        private def record_recovery_probe_failure(error)
          request_tracker.record_failure(error)
        end

        # @param state_snapshot [Stoplight::Domain::StateSnapshot]
        # @return [void]
        private def enter_recovery(state_snapshot)
          return if state_snapshot.recovery_started?

          data_store.transition_to_color(config, Color::YELLOW)
          data_store.clear_metrics(config)
          notifiers.each do |notifier|
            notifier.notify(config, Color::RED, Color::YELLOW, nil)
          end
        end

        # @return [Boolean]
        def ==(other)
          super &&
            config == other.config &&
            notifiers == other.notifiers &&
            data_store == other.data_store &&
            request_tracker == other.request_tracker &&
            red_run_strategy == other.red_run_strategy
        end
      end
    end
  end
end

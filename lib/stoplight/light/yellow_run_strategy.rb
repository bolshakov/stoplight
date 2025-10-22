# frozen_string_literal: true

module Stoplight
  class Light
    # Defines how the light executes when it is yellow.
    #
    # This strategy clears failures after successful execution and notifies
    # about color switch from Red to Green. It also handles errors by either
    # raising them or invoking a fallback if provided.
    #
    # @api private
    class YellowRunStrategy < RunStrategy
      # @!attribute [r] traffic_recovery
      #   @return [Stoplight::TrafficRecovery::Base]
      protected attr_reader :traffic_recovery

      # @!attribute [r] notifiers
      #   @return [Stoplight::Notifier::Base]
      protected attr_reader :notifiers

      # @param config [Stoplight::Domain::Config]
      # @param data_store [Stoplight::DataStore::Base]
      # @param traffic_recovery [Stoplight::TrafficRecovery::Base]
      # @param notifiers [Array<Stoplight::Notifier::Base>]
      def initialize(config:, data_store:, traffic_recovery:, notifiers:)
        super(config:, data_store:)
        @traffic_recovery = traffic_recovery
        @notifiers = notifiers
      end

      # Executes the provided code block when the light is in the yellow state.
      #
      # @param fallback [Proc, nil] A fallback proc to execute in case of an error.
      # @param metadata [Stoplight::Metadata] Metadata capturing the current state of the light.
      # @yield The code block to execute.
      # @return [Object] The result of the code block if successful.
      # @raise [Exception] Re-raises the error if it is not tracked or no fallback is provided.
      def execute(fallback, metadata:, &code)
        transition_to_yellow(metadata:)
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
        metadata = data_store.record_recovery_probe_success(config)

        recover(metadata)
      end

      private def record_recovery_probe_failure(error)
        failure = Failure.from_error(error)
        metadata = data_store.record_recovery_probe_failure(config, failure)

        recover(metadata)
      end

      # @param metadata [Stoplight::Metadata]
      # @return [void]
      def transition_to_yellow(metadata:)
        return unless metadata.color == Color::YELLOW

        if metadata.recovery_scheduled_after && data_store.transition_to_color(config, Color::YELLOW)
          notifiers.each do |notifier|
            notifier.notify(config, Color::RED, Color::YELLOW, nil)
          end
        end
      end

      private def recover(metadata)
        recovery_result = traffic_recovery.determine_color(config, metadata)

        case recovery_result
        when TrafficRecovery::GREEN
          if data_store.transition_to_color(config, Color::GREEN)
            notifiers.each do |notifier|
              notifier.notify(config, Color::YELLOW, Color::GREEN, nil)
            end
          end
        when TrafficRecovery::YELLOW
          if data_store.transition_to_color(config, Color::YELLOW)
            notifiers.each do |notifier|
              notifier.notify(config, Color::RED, Color::YELLOW, nil)
            end
          end
        when TrafficRecovery::RED
          if data_store.transition_to_color(config, Color::RED)
            notifiers.each do |notifier|
              notifier.notify(config, Color::YELLOW, Color::RED, nil)
            end
          end
        when TrafficRecovery::PASS
          # No state change, do nothing
        else
          raise "recovery strategy returned an expected color: #{recovery_result}"
        end
      end

      # @return [Boolean]
      def ==(other)
        super && traffic_recovery == other.traffic_recovery && notifiers == other.notifiers
      end
    end
  end
end

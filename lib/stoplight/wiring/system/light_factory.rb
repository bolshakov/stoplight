# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightFactory < Wiring::LightFactory
        # @dynamic system
        attr_reader :system

        def initialize(system:, settings:)
          @system = system
          @settings = settings

          super(settings:)
        end

        def with(
          name: T.undefined,
          cool_off_time: T.undefined,
          threshold: T.undefined,
          recovery_threshold: T.undefined,
          window_size: T.undefined,
          tracked_errors: T.undefined,
          skipped_errors: T.undefined,
          data_store: T.undefined,
          error_notifier: T.undefined,
          notifiers: T.undefined,
          traffic_control: T.undefined,
          traffic_recovery: T.undefined
        )
          self.class.new(
            system:,
            settings: settings.extend_with(
              name:,
              cool_off_time:,
              threshold:,
              recovery_threshold:,
              window_size:,
              tracked_errors:,
              skipped_errors:,
              data_store:,
              error_notifier:,
              notifiers:,
              traffic_control:,
              traffic_recovery:
            )
          )
        end

        class InternalLightFactory < Wiring::LightFactory
          def initialize
          end

          def with(**settings) # steep:ignore
            raise NotImplementedError, "You're not allowed to extend system lights"
          end
        end

        private def light_builder(config:)
          System::LightBuilder.new(system:, factory: light_factory, config:)
        end

        private def light_factory = InternalLightFactory.new
      end
    end
  end
end

# frozen_string_literal: true

require "dry-struct"

module Stoplight
  class Light < CircuitBreaker
    # This class is used to define the default configuration for the +Stoplight::Light+.
    #
    # @api private
    class DefaultConfig < Dry::Struct
      schema schema.strict
      transform_keys(&:to_sym)

      attribute :cool_off_time, Types::Coercible::Float.default { Default::COOL_OFF_TIME }
      attribute :data_store, Types::DataStore.default { Default::DATA_STORE }
      attribute :error_notifier, Types::ErrorNotifier.default { Default::ERROR_NOTIFIER }
      attribute :notifiers, Types::Array.of(Types::Notifier).default { Default::NOTIFIERS }
      attribute :threshold, Types::Integer.default { Default::THRESHOLD }
      attribute :window_size, (Types::Integer | Types::Float).default { Default::WINDOW_SIZE }
      attribute :tracked_errors, Types::Array.of(Types::TrackedError).default { Default::TRACKED_ERRORS }
      attribute :skipped_errors, Types::Array.of(Types::SkippedError).default { [] }.constructor { |value|
        if value == Dry::Core::Undefined
          Stoplight::Default::SKIPPED_ERRORS
        else
          Set[*value, *Stoplight::Default::SKIPPED_ERRORS].to_a
        end
      }

      # Updates the configuration with new settings and returns a new instance.
      #
      # @return [Stoplight::Light::Config]
      def with(**settings)
        self.class.new(**to_h.merge(settings))
      end
    end
  end
end

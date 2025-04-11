# frozen_string_literal: true

require "dry-struct"

module Stoplight
  class Light < CircuitBreaker
    # This class is used to define the default configuration for the +Stoplight::Light+.
    #
    # @api private
    class BaseConfig < Dry::Struct
      attribute? :cool_off_time, Types::Coercible::Float
      attribute? :data_store, Types::DataStore
      attribute? :error_notifier, Types::ErrorNotifier
      attribute? :notifiers, Types::Array.of(Types::Notifier)
      attribute? :threshold, Types::Integer
      attribute? :window_size, (Types::Integer | Types::Float)
      attribute? :tracked_errors, Types::Array.of(Types::TrackedError)
      attribute? :skipped_errors, Types::Array.of(Types::SkippedError).constructor { |value|
        if value == Dry::Core::Undefined
          Stoplight::Default::SKIPPED_ERRORS
        else
          Set[*value, *Stoplight::Default::SKIPPED_ERRORS].to_a
        end
      }
    end
  end
end

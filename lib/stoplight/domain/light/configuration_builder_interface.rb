# frozen_string_literal: true

require "forwardable"

module Stoplight
  module Domain
    class Light
      # Implements light configuration behavior
      # steep:ignore:start
      module ConfigurationBuilderInterface
        # Configures data store to be used with this circuit breaker
        #
        # @example
        #   Stoplight('example')
        #     .with_data_store(Stoplight::DataStore::Memory.new)
        #
        # @param data_store [DataStore::Base]
        # @return [Stoplight::Light]
        # @deprecated
        def with_data_store(data_store)
          deprecate(<<~MSG)
            Light#with_data_store is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_data_store(data_stare)

            Configure correctly from the start:
              Stoplight('api-call', data_store:)
          MSG
          with_without_warning(data_store:)
        end

        # Configures cool off time. Stoplight automatically tries to recover
        # from the red state after the cool off time.
        #
        # @example
        #   Stoplight('example')
        #     .cool_off_time(60)
        #
        # @param cool_off_time [Numeric] number of seconds
        # @return [Stoplight::Light]
        # @deprecated
        def with_cool_off_time(cool_off_time)
          deprecate(<<~MSG)
            Light#with_cool_off_time is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_cool_off_time(cool_off_time)

            Configure correctly from the start:
              Stoplight('api-call', cool_off_time:)
          MSG
          with_without_warning(cool_off_time:)
        end

        # Configures custom threshold. After this number of failures Stoplight
        # switches to the red state:
        #
        # @example
        #   Stoplight('example')
        #     .with_threshold(5)
        #
        # @param threshold [Numeric]
        # @return [Stoplight::Light]
        # @deprecated
        def with_threshold(threshold)
          deprecate(<<~MSG)
            Light#with_threshold is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_threshold(threshold)

            Configure correctly from the start:
              Stoplight('api-call', threshold:)
          MSG
          with_without_warning(threshold:)
        end

        # Configures custom window size which Stoplight uses to count failures. For example,
        #
        # @example
        #   Stoplight('example')
        #     .with_threshold(5)
        #     .with_window_size(60)
        #
        # The above example will turn to red light only when 5 errors happen
        # within 60 seconds period.
        #
        # @param window_size [Numeric] number of seconds
        # @return [Stoplight::Light]
        # @deprecated
        def with_window_size(window_size)
          deprecate(<<~MSG)
            Light#with_window_size is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_window_size(window_size)

            Configure correctly from the start:
              Stoplight('api-call', window_size:)
          MSG
          with_without_warning(window_size:)
        end

        # Configures custom notifier
        #
        # @example
        #   io = StringIO.new
        #   notifier = Stoplight::Notifier::IO.new(io)
        #   Stoplight('example')
        #     .with_notifiers([notifier])
        #
        # @param notifiers [Array<Notifier::Base>]
        # @return [Stoplight::Light]
        # @deprecated
        def with_notifiers(notifiers)
          deprecate(<<~MSG)
            Light#with_notifiers is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_notifiers(notifiers)

            Configure correctly from the start:
              Stoplight('api-call', notifiers:)
          MSG
          with_without_warning(notifiers:)
        end

        # @param error_notifier [Proc]
        # @return [Stoplight::Light]
        # @api private
        # @deprecated
        def with_error_notifier(&error_notifier)
          deprecate(<<~MSG)
            Light#with_error_notifier is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_error_notifier { |error| warn error }

            Configure correctly from the start:
              Stoplight('api-call', error_notifier: ->(error) { warn error })
          MSG
          with_without_warning(error_notifier: error_notifier)
        end

        # Configures a custom list of tracked errors that counts toward the threshold.
        #
        # @example
        #   light = Stoplight('example')
        #     .with_tracked_errors(TimeoutError, NetworkError)
        #   light.run { call_external_service }
        #
        # In the example above, the +TimeoutError+ and +NetworkError+ exceptions
        # will be counted towards the threshold for moving the circuit breaker into the red state.
        # If not configured, the default tracked error is +StandardError+.
        #
        # @param tracked_errors [Array<StandardError>]
        # @return [Stoplight::Light]
        # @deprecated
        def with_tracked_errors(*tracked_errors)
          deprecate(<<~MSG)
            Light#with_tracked_errors is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_tracked_errors(TimeoutError, NetworkError)

            Configure correctly from the start:
              Stoplight('api-call', tracked_errors: [TimeoutError, NetworkError])
          MSG
          with_without_warning(tracked_errors:)
        end

        # Configures a custom list of skipped errors that do not count toward the threshold.
        # Typically, such errors does not represent a real failure and handled somewhere else
        # in the code.
        #
        # @example
        #   light = Stoplight('example')
        #    .with_skipped_errors(ActiveRecord::RecordNotFound)
        #   light.run { User.find(123) }
        #
        # In the example above, the +ActiveRecord::RecordNotFound+ doesn't
        # move the circuit breaker into the red state.
        #
        # @param skipped_errors [Array<Exception>]
        # @return [Stoplight::Light]
        # @deprecated
        def with_skipped_errors(*skipped_errors)
          deprecate(<<~MSG)
            Light#with_skipped_errors is deprecated and will be removed in v7.0.0.

            Circuit breakers should be configured once at creation, not cloned with
            modifications.

            Instead of:
              light = Stoplight('api-call')
              modified = light.with_skipped_errors(ActiveRecord::RecordNotFound)

            Configure correctly from the start:
              Stoplight('api-call', skipped_errors: [ActiveRecord::RecordNotFound])
          MSG
          with_without_warning(skipped_errors:)
        end
      end
      # steep:ignore:end
    end
  end
end

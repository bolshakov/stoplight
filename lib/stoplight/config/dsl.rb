# frozen_string_literal: true

module Stoplight
  module Config
    # This is a DSL for configuring Stoplight settings. It is responsible for
    # transforming the provided settings into a format that can be used by Stoplight.
    #
    # @api private
    class DSL
      def transform(settings)
        if settings.has_key?(:data_store)
          settings[:data_store] = build_data_store(settings[:data_store])
        end

        if settings.has_key?(:notifiers)
          settings[:notifiers] = build_notifiers(settings[:notifiers])
        end

        if settings.has_key?(:tracked_errors)
          settings[:tracked_errors] = build_tracked_errors(settings[:tracked_errors])
        end

        if settings.has_key?(:skipped_errors)
          settings[:skipped_errors] = build_skipped_errors(settings[:skipped_errors])
        end

        if settings.has_key?(:cool_off_time)
          settings[:cool_off_time] = build_cool_off_time(settings[:cool_off_time])
        end

        if settings.has_key?(:traffic_control)
          settings[:traffic_control] = build_traffic_control(settings[:traffic_control])
        end
        settings
      end

      private

      def build_data_store(data_store)
        DataStore::FailSafe.wrap(data_store)
      end

      def build_notifiers(notifiers)
        notifiers.map { |notifier| Notifier::FailSafe.wrap(notifier) }
      end

      def build_tracked_errors(tracked_error)
        Array(tracked_error)
      end

      def build_skipped_errors(skipped_errors)
        Array(skipped_errors)
      end

      def build_cool_off_time(cool_off_time)
        cool_off_time.to_i
      end

      def build_traffic_control(traffic_control)
        case traffic_control
        in Stoplight::TrafficControl::Base
          traffic_control
        in :consecutive_errors
          Stoplight::TrafficControl::ConsecutiveErrors.new
        in :error_rate
          Stoplight::TrafficControl::ErrorRate.new
        in {error_rate: error_rate_settings}
          Stoplight::TrafficControl::ErrorRate.new(**error_rate_settings)
        else
          raise Error::ConfigurationError, <<~ERROR
            unsupported traffic_control strategy provided (`#{traffic_control}`). Supported options:
              * Stoplight::TrafficControl::ConsecutiveErrors
              * Stoplight::TrafficControl::ErrorRate
          ERROR
        end
      end
    end
  end
end

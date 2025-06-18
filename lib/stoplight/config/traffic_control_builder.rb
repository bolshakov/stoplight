# frozen_string_literal: true

module Stoplight
  module Config
    module TrafficControlBuilder
      def build_traffic_control(tc)
        case tc
        when :error_rate
          Stoplight::TrafficControl::ErrorRate.new
        when :consecutive_failures
          Stoplight::TrafficControl::ConsecutiveFailures.new
        when Hash
          if tc.key?(:error_rate)
            opts = tc[:error_rate] || {}
            Stoplight::TrafficControl::ErrorRate.new(**opts.transform_keys { |k| (k == :min_requests) ? :min_sample_size : k })
          elsif tc.key?(:consecutive_failures)
            opts = tc[:consecutive_failures] || {}
            Stoplight::TrafficControl::ConsecutiveFailures.new(**opts)
          else
            raise ArgumentError, "Unknown traffic_control hash: \\#{tc.inspect}"
          end
        else
          tc
        end
      end
    end
  end
end

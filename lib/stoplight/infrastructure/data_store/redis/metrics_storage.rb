# frozen_string_literal: true

require "json"

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class MetricsStorage < Domain::Storage::Metrics
          KEY_SEPARATOR = ":"
          KEY_PREFIX = %w[stoplight v5].join(KEY_SEPARATOR)

          # Generates a Redis key by joining the prefix with the provided pieces.
          #
          # @param pieces [Array<String, Integer>] Parts of the key to be joined.
          # @return [String] The generated Redis key.
          # @api private
          private def key(*pieces)
            [KEY_PREFIX, *pieces].join(KEY_SEPARATOR)
          end

          # @param exception [StandardError]
          # @param timestamp [Float]
          private def serialize_exception(exception, timestamp:)
            JSON.generate(
              {
                error: {
                  class: exception.class.name,
                  message: exception.message
                },
                time: timestamp
              }
            )
          end

          # @param failure_json [String, nil]
          # @return [Stoplight::Domain::Failure, nil]
          private def deserialize_failure(failure_json)
            return if failure_json.nil?

            object = JSON.parse(failure_json)
            error_object = object["error"]

            error_class = error_object["class"]
            error_message = error_object["message"]
            time = Time.at(object["time"])

            Domain::Failure.new(error_class, error_message, time)
          end

          private def current_time
            Time.now
          end
        end
      end
    end
  end
end

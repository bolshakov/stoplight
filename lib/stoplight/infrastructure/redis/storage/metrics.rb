# frozen_string_literal: true

require "json"

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class Metrics
          def serialize_exception(exception, timestamp:)
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

          def deserialize_failure(failure_json)
            return if failure_json.nil?

            object = JSON.parse(failure_json)
            error_object = object["error"]

            error_class = error_object["class"]
            error_message = error_object["message"]
            time = Time.at(object["time"])

            Domain::Failure.new(error_class, error_message, time)
          end

          private def metrics_ttl = 86400 * 7 # 7 days
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      class DataStore
        class Metrics
          attr_accessor :consecutive_errors
          attr_accessor :consecutive_successes
          attr_accessor :last_error
          attr_accessor :last_success_at

          def initialize(consecutive_errors: 0, consecutive_successes: 0, last_error: nil, last_success_at: nil)
            @consecutive_errors = consecutive_errors
            @consecutive_successes = consecutive_successes
            @last_error = last_error
            @last_success_at = last_success_at
          end

          def last_error_at
            @last_error&.time
          end
        end
      end
    end
  end
end

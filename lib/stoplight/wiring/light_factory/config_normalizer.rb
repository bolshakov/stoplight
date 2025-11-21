# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightFactory
      # Normalizes user-provided configuration values into canonical forms.
      #
      # Handles common user convenience patterns:
      # - Single error class → Array of error classes
      # - Numeric cool_off_time → Integer
      #
      # @example
      #   config = Config.empty.with(
      #     tracked_errors: StandardError,  # Single class
      #     cool_off_time: 30.5             # Float
      #   )
      #
      #   normalized = ConfigNormalizer.call(config)
      #   normalized.tracked_errors #=> [StandardError]  # Array
      #   normalized.cool_off_time  #=> 30               # Integer
      #
      # @api private
      class ConfigNormalizer
        class << self
          def call(config) = new(config).call
        end

        # @!attribute config
        #   @return [Stoplight::Domain::Config]
        private attr_reader :config

        # @param [Stoplight::Domain::Config]
        def initialize(config)
          @config = config
        end

        # @return [Stoplight::Domain::Config]
        def call
          config
            .then { |c| normalize_tracked_errors(c) }
            .then { |c| normalize_skipped_errors(c) }
            .then { |c| normalize_cool_off_time(c) }
        end

        private def normalize_tracked_errors(config)
          if config.tracked_errors.is_a?(Array)
            config
          else
            config.with(tracked_errors: Array(config.tracked_errors))
          end
        end

        private def normalize_skipped_errors(config)
          if config.skipped_errors.is_a?(Array)
            config
          else
            config.with(skipped_errors: Array(config.skipped_errors))
          end
        end

        private def normalize_cool_off_time(config)
          if config.cool_off_time.is_a?(Integer)
            config
          else
            config.with(cool_off_time: config.cool_off_time.to_i)
          end
        end
      end
    end
  end
end

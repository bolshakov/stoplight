# frozen_string_literal: true

module Stoplight
  class EvaluationStrategy
    # @param config [Stoplight::Light::Config]
    # @param metadata [Stoplight::Metadata]
    # @return [Boolean]
    def evaluate(config, metadata)
      if config.window_size == Float::INFINITY
        metadata.consecutive_failures >= config.threshold
      else
        [metadata.consecutive_failures, metadata.failures].min >= config.threshold
      end
    end
  end
end

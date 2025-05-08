# frozen_string_literal: true

module Stoplight
  class EvaluationStrategy
    # @param config [Stoplight::Light::Config]
    # @param metadata [Stoplight::DataStore::Metadata]
    # @return [Boolean]
    def evaluate(config, metadata)
      [metadata.consecutive_failures, metadata.failures].min >= config.threshold
    end
  end
end

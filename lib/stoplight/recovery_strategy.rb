# frozen_string_literal: true

module Stoplight
  class RecoveryStrategy
    # @param config [Stoplight::Light::Config]
    # @param metadata [Stoplight::DataStore::Metadata]
    # @return [Stoplight::Color::YELLOW, Stoplight::Color::GREEN, Stoplight::Color::RED]
    def evaluate(config, metadata)
      if metadata.recovery_started_at < metadata.last_success_at
        Color::GREEN
      else
        Color::RED
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  class RecoveryStrategy
    # @param config [Stoplight::Light::Config]
    # @param metadata [Stoplight::Metadata]
    # @return [Stoplight::Color::YELLOW, Stoplight::Color::GREEN, Stoplight::Color::RED]
    def evaluate(config, metadata)
      recovery_started_at = metadata.recovery_started_at || metadata.recovery_scheduled_after
      last_success_at = metadata.last_success_at
      if last_success_at && recovery_started_at <= last_success_at
        Color::GREEN
      else
        Color::RED
      end
    end
  end
end

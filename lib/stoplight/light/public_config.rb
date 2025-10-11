# frozen_string_literal: true

module Stoplight
  class Light
    class PublicConfig
      # @!attribute [r] config
      #   @return [Stoplight::Light::Config]
      #   @api private
      private attr_reader :config

      def initialize(config)
        @config = config
      end

      def recovery_stage_starts_at
        recovery_scheduled_after = config.data_store.get_metadata(config).recovery_scheduled_after
        current_time = Time.now

        (recovery_scheduled_after > current_time) ? current_time : current_time + recovery_scheduled_after
      end
    end
  end
end

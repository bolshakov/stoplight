# frozen_string_literal: true

module Stoplight
  class ConfigProvider < ConfigX::ConfigFactory
    class << self
      def default_env_prefix = "STOPLIGHT"

      def default_dir_name = "stoplight"

      def default_file_name = "stoplight"

      def default_config_class = Stoplight::Config
    end

    private

    def sources
      [
        {default: Stoplight.__programmatic_settings},
        *super
      ]
    end
  end
end

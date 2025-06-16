# frozen_string_literal: true

begin
  require "rails/generators"
rescue LoadError
  raise <<~WARN
    Currently generators are only available for Rails applications
  WARN
end

module Stoplight
  module Generators
    class InstallGenerator < ::Rails::Generators::Base # :nodoc:
      source_root File.expand_path("templates", __dir__)

      class_option :with_admin_panel, type: :boolean, optional: true,
        desc: "Define whether to set up admin panel"

      ROUTES_PATH = "config/routes.rb"
      STOPLIGHT_CONFIG_TEMPLATE = "stoplight.rb.erb"
      INITIALIZERS_PATH = "config/initializers"
      AFTER_INSTALL_NOTIFICATION = <<~TEXT
        \nThank you for using stoplight!
        Now to finish configuration go to 'config/initializers/stoplight.rb' to set up connection to Redis.\n
      TEXT

      def generate_initializer
        initializer_template = STOPLIGHT_CONFIG_TEMPLATE
        copy_file initializer_template, "#{INITIALIZERS_PATH}/stoplight.rb"
      end

      def generate_admin_panel
        if options[:with_admin_panel]
          spacing = " " * 2
          route = "mount Stoplight::Admin => '/stoplights'"
          insert_string = "#{spacing}#{route}\n"

          inject_into_file ROUTES_PATH, insert_string, after: ".application.routes.draw do\n"
        end
      end

      def redis_configuration_notification
        print AFTER_INSTALL_NOTIFICATION
      end
    end
  end
end

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
        Now to finish configuration:
        * Run `bundle` from the project root to install new gems
        * Go to 'config/initializers/stoplight.rb' to set up connection to Redis.\n
      TEXT

      STOPLIGHT_ADMIN_ROUTE = <<-RUBY
  mount Stoplight::Admin => '/stoplights'
      RUBY

      STOPLIGHT_AUTH = <<-RUBY
  Stoplight::Admin.use(Rack::Auth::Basic) do |username, password|
    username == ENV["STOPLIGHT_ADMIN_USERNAME"] && password == ENV["STOPLIGHT_ADMIN_PASSWORD"]
  end
      RUBY

      def generate_redis_gem
        if options[:with_admin_panel]
          conf = "\ngem 'redis'"
          inject_into_file "Gemfile", conf
        end
      end

      def generate_sinatra_deps
        if options[:with_admin_panel]
          conf = <<~RUBY
            gem 'sinatra', require: false
            gem 'sinatra-contrib', require: false
          RUBY

          inject_into_file "Gemfile", "\n#{conf}"
        end
      end

      def generate_initializer
        initializer_template = STOPLIGHT_CONFIG_TEMPLATE
        copy_file initializer_template, "#{INITIALIZERS_PATH}/stoplight.rb"
      end

      def generate_admin_panel
        if options[:with_admin_panel]
          route_config = "#{STOPLIGHT_AUTH}#{STOPLIGHT_ADMIN_ROUTE}\n"

          inject_into_file ROUTES_PATH, route_config, after: ".application.routes.draw do\n"
        end
      end

      def redis_configuration_notification
        print AFTER_INSTALL_NOTIFICATION
      end
    end
  end
end

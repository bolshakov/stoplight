# coding: utf-8

module Stoplight
  # @example
  #   class ApplicationController
  #     around_action Stoplight::Filter
  #     # ...
  class Filter
    def self.around(controller, &block)
      controller_name = controller.params['controller']
      action_name = controller.params['action']

      Stoplight::Light.new
        .with_name("#{controller_name}/#{action_name}")
        .with_code(&block)
        .with_fallback do
          controller.render(nothing: true, status: :service_unavailable)
        end
        .run
    end
  end
end

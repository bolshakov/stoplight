# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    # A +Stoplight::Light+ configuration object.
    # @api private
    class Config < BaseConfig
      schema schema.strict
      transform_keys(&:to_sym)

      attribute :name, Types::Coercible::String

      # Updates the configuration with new settings and returns a new instance.
      #
      # @return [Stoplight::Light::Config]
      def with(**settings)
        self.class.new(**to_h.merge(settings))
      end
    end
  end
end

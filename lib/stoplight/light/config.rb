# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    # A +Stoplight::Light+ configuration object.
    class Config < DefaultConfig
      attribute :name, Types::Coercible::String
    end
  end
end

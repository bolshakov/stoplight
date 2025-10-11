# frozen_string_literal: true

module Stoplight
  module Error
    Base = Class.new(StandardError)
    ConfigurationError = Class.new(Base)
    IncorrectColor = Class.new(Base)

    class RedLight < Base
      attr_reader :config

      def initialize(message, public_config)
        @config = public_config
        super(message)
      end
    end
  end
end

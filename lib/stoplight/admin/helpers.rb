# frozen_string_literal: true

module Stoplight
  module Admin
    module Helpers
      COLORS = [
        GREEN = Stoplight::Color::GREEN,
        YELLOW = Stoplight::Color::YELLOW,
        RED = Stoplight::Color::RED
      ].freeze

      # @return [Stoplight::Admin::Dependencies]
      def dependencies
        Dependencies.new(data_store: settings.data_store)
      end
    end
  end
end

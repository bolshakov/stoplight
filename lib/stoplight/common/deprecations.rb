# frozen_string_literal: true

module Stoplight
  module Common
    module Deprecations
      extend self

      def deprecate(message) = warn("[DEPRECATION] #{message}")
    end
  end
end

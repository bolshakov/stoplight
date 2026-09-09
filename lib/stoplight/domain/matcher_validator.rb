# frozen_string_literal: true

module Stoplight
  module Domain
    class MatcherValidator
      class << self
        def call(error_matcher)
          name = error_matcher.is_a?(Module) ? error_matcher.name : nil
          raise ArgumentError, message(error_matcher) if name.nil?

          name
        end

        private

        def message(error_matcher)
          "error matcher #{error_matcher.inspect} must be a named class or module (e.g. StandardError, " \
            "or a custom class/module overriding `===`) - procs, anonymous classes, and instances have no " \
            "stable name and cannot be used here."
        end
      end
    end
  end
end

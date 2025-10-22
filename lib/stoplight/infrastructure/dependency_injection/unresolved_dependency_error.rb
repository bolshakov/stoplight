# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DependencyInjection
      class UnresolvedDependencyError < Error::Base
        def initialize(key)
          super("Unable to resolve dependency: `#{key}`")
        end
      end
    end
  end
end

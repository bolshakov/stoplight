# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DependencyInjection
      class UnresolvedDependencyError < Domain::Error::Base
        def initialize(key)
          super("Unable to resolve dependency: `#{key}`")
        end
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  class Admin
    module Actions
      # @abstract
      class Action
        # Unwinds to Sinatra's route dispatch via `throw :halt`, skipping the rest of the
        # action and the route block, and using +status+ as the response status.
        def halt(status)
          throw :halt, status
        end
      end
    end
  end
end

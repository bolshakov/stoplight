# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Notifier
      # @see Base
      class Logger
        include Generic

        def logger
          @object
        end

        def put(message)
          logger.warn(message)
        end
      end
    end
  end
end

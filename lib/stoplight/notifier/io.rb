# frozen_string_literal: true

module Stoplight
  module Notifier
    # @see Base
    class IO < Base
      include Generic

      # @return [::IO]
      def io
        @object
      end

      private

      def put(message)
        io.puts(message)
      end
    end
  end
end

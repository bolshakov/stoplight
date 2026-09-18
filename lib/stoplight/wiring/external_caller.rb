# frozen_string_literal: true

module Stoplight
  module Wiring
    # Locates the application code that called into Stoplight, so configuration errors point at
    # the light's call site instead of Stoplight's own internals.
    #
    # @api private
    module ExternalCaller
      LIB_ROOT = "#{File.expand_path("../../..", __FILE__)}/"

      class << self
        def backtrace
          frames = caller_locations(1) || []
          external = frames.reject { |frame| internal?(frame) }
          external = frames if external.empty?
          external.map(&:to_s)
        end

        private def internal?(frame)
          path = frame.path.to_s
          path.start_with?(LIB_ROOT, "<internal:")
        end
      end
    end
  end
end

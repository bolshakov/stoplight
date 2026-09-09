# frozen_string_literal: true

module Stoplight
  module Domain
    module Telemetry
      # Wraps every published event.
      Envelope = Data.define(
        :system_name,
        :light_name,
        :occurred_at,
        :payload
      )
    end
  end
end

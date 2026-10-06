# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      LightSummary = Data.define(:id, :name, :color, :locked)

      class LightSummary
        def locked? = locked
      end
    end
  end
end

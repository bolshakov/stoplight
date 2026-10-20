# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      LightSummary = Data.define(:id, :name, :color, :lock_state)

      class LightSummary
        def locked? = lock_state != Stoplight::State::UNLOCKED
      end
    end
  end
end

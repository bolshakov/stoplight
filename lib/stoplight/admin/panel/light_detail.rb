# frozen_string_literal: true

module Stoplight
  class Admin
    class Panel
      LightDetail = Data.define(
        :id, :name, :color, :lock_state, :last_error, :recovery_scheduled_after, :consecutive_successes,
        :recovery_threshold
      )

      class LightDetail
        def locked? = lock_state != Stoplight::State::UNLOCKED

        def recovery_in_seconds
          return nil unless recovery_scheduled_after

          [0, (recovery_scheduled_after - Time.now.utc).ceil].max
        end
      end
    end
  end
end

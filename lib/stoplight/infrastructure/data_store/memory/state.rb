# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Memory
        class State
          attr_accessor :recovered_at
          attr_accessor :locked_state
          attr_accessor :recovery_scheduled_after
          attr_accessor :recovery_started_at
          attr_accessor :breached_at

          def initialize
            @locked_state = Domain::State::UNLOCKED
          end
        end
      end
    end
  end
end

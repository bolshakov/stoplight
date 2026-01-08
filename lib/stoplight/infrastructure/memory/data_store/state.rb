# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      class DataStore
        class State
          # @dynamic recovered_at
          attr_accessor :recovered_at
          # @dynamic locked_state
          attr_accessor :locked_state
          # @dynamic recovery_scheduled_after
          attr_accessor :recovery_scheduled_after
          # @dynamic recovery_started_at
          attr_accessor :recovery_started_at
          # @dynamic breached_at
          attr_accessor :breached_at

          def initialize
            @locked_state = Stoplight::State::UNLOCKED
          end
        end
      end
    end
  end
end

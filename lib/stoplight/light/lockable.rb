# frozen_string_literal: true

module Stoplight
  class Light
    # The Lockable module implements the behavior of locking and unlocking the light.
    # Light can be locked in either a State::LOCKED_RED or State::LOCKED_GREEN state.
    # By locking the light, you force it always to run code with the chosen light color.
    #
    # ==== Examples
    #
    #   light = Stoplight('example-locked') { true }
    #   # => #<Stoplight::Light:..>
    #   light.run
    #   # => true
    #   light.lock(Stoplight::Color::RED)
    #   # => "locked_red"
    #   light.run
    #   # Stoplight::Error::RedLight: example-locked
    #   light.unlock
    #   # => "unlocked"
    #   light.run
    #   # => true
    module Lockable
      def lock(color)
        state = case color
                when Color::RED then State::LOCKED_RED
                when Color::GREEN then State::LOCKED_GREEN
                else raise Error::IncorrectColor
                end

        safely { data_store.set_state(self, state) }
      end

      def unlock
        safely { data_store.set_state(self, Stoplight::State::UNLOCKED) }
      end
    end
  end
end

# frozen_string_literal: true

module Stoplight
  class Light
    # The Lockable module implements the behavior of locking and unlocking the light.
    # Light can be locked in either a State::LOCKED_RED or State::LOCKED_GREEN state.
    # By locking the light, you force it always to run code with the chosen light color.
    #
    # @example
    #   light = Stoplight('example-locked') { true }
    #   # => #<Stoplight::Light:..>
    #   light.run
    #   # => true
    #   light.lock(Stoplight::Color::RED)
    #   # => #<Stoplight::Light:..>
    #   light.run
    #   # => Stoplight::Error::RedLight: example-locked
    #   light.unlock
    #   # => #<Stoplight::Light:..>
    #   light.run
    #   # => true
    module Lockable
      # Locks light in either State::LOCKED_RED or State::LOCKED_GREEN
      #
      # @example
      #   light = Stoplight('example-locked') { true }
      #   # => #<Stoplight::Light:..>
      #   light.lock(Stoplight::Color::RED)
      #   # => #<Stoplight::Light:..>
      #
      # @param color [String] should be either Color::RED or Color::GREEN
      # @return [Stoplight::Light] returns locked light
      def lock(color)
        state = case color
                when Color::RED then State::LOCKED_RED
                when Color::GREEN then State::LOCKED_GREEN
                else raise Error::IncorrectColor
                end

        safely { data_store.set_state(self, state) }

        self
      end

      # Unlocks light and sets it's state to State::UNLOCKED
      #
      # @example
      #   light = Stoplight('example-locked') { true }
      #   # => #<Stoplight::Light:..>
      #   light.lock(Stoplight::Color::RED)
      #   # => "locked_red"
      #   light.unlock
      #   # => #<Stoplight::Light:..>
      #
      # @return [Stoplight::Light] returns unlocked light
      def unlock
        safely { data_store.set_state(self, Stoplight::State::UNLOCKED) }

        self
      end
    end
  end
end

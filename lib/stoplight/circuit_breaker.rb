# frozen_string_literal: true

module Stoplight
  # This class is kept for the backward compatibility so that each instance of
  # +Stoplight::Light+ is also an instance of +Stoplight::CircuitBreaker+.
  class CircuitBreaker
  end
end

# frozen_string_literal: true

class NullStateStore
  def state_snapshot = raise ArgumentError
  def set_state(state) = raise ArgumentError
  def transition_to_color(color) = raise ArgumentError
  def clear = raise ArgumentError
end

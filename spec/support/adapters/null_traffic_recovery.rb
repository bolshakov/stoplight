# frozen_string_literal: true

class NullTrafficRecovery
  def check_compatibility = raise NotImplementedError
  def determine_color(config, metrics) = raise NotImplementedError
  def ==(other) = raise NotImplementedError
end

# frozen_string_literal: true

class NullTrafficControl
  def check_compatibility = raise NotImplementedError
  def stop_traffic?(config, metrics) = raise NotImplementedError
  def ==(other) = raise NotImplementedError
end

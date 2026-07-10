class NullClock
  def current_time = raise NotImplementedError
  def monotonic_time = raise NotImplementedError
  def at(ts) = raise NotImplementedError
end

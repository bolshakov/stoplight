class NullClock
  def current_time = raise NotImplementedError
  def monotonic_millis = raise NotImplementedError
  def monotonic_seconds = raise NotImplementedError
  def at(ts) = raise NotImplementedError
end

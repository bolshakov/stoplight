class NullMetricsStore
  def metrics_snapshot = raise NotImplementedError
  def record_success = raise NotImplementedError
  def record_failure(error) = raise NotImplementedError
  def clear = raise NotImplementedError
end

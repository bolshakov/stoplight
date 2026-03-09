# frozen_string_literal: true

class NullDataStore
  def names = raise NotImplementedError
  def get_metrics(config) = raise NotImplementedError
  def get_recovery_metrics(config) = raise NotImplementedError
  def get_state_snapshot(config) = raise NotImplementedError
  def clear_metrics(config) =raise NotImplementedError
  def clear_recovery_metrics(config) = raise NotImplementedError
  def record_failure(config, exception) = raise NotImplementedError
  def record_success(config) = raise NotImplementedError
  def record_recovery_probe_failure(config, failure) = raise NotImplementedError
  def record_recovery_probe_success(config) = raise NotImplementedError
  def set_state(config, state) = raise NotImplementedError
  def acquire_recovery_lock(config) = raise NotImplementedError
  def release_recovery_lock(lock) = raise NotImplementedError
  def transition_to_color(config, color) = raise NotImplementedError
  def delete_light(config) = raise NotImplementedError
end

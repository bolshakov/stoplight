# frozen_string_literal: true

class NullRecoveryLockStore
  def acquire_lock = raise NotImplementedError
  def release_lock(_token) = raise NotImplementedError
end

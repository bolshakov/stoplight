# frozen_string_literal: true

module Stoplight
  module Domain
    # Token representing an acquired recovery lock.
    #
    # Returned by +DataStore#acquire_recovery_lock+ and passed to
    # +DataStore#release_recovery_lock+ to identify which lock to release.
    #
    # The actual locking mechanism lives in DataStore implementations,
    # not in these tokens.
    class RecoveryLockToken
    end
  end
end

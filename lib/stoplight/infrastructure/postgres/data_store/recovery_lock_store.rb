# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    # steep:ignore:start
    module Postgres
      class DataStore
        # Distributed recovery lock using Postgres INSERT … ON CONFLICT DO UPDATE … RETURNING.
        #
        # Clock note: unlike every other operation in this adapter, this class deliberately
        # uses the database clock (`now()`) for both setting and evaluating the expires_at TTL.
        # A DB-clock TTL is self-consistent across application nodes regardless of clock skew,
        # so no Ruby/Timecop clock is needed or appropriate here.
        #
        # Lock Acquisition:
        # - Generates a UUID token per attempt; the token identifies the exact holder.
        # - Uses atomic INSERT … ON CONFLICT to either insert a new row (lock free) or
        #   steal an expired row (lock timed out) — all in a single round-trip.
        # - Returns a RecoveryLockToken on success, nil if the lock is currently held.
        #
        # Lock Release:
        # - Deletes by (light, token) so only the holder can release its own lock.
        # - Best-effort; the expires_at TTL handles crash recovery automatically.
        #
        # Failure Modes:
        # - Lock contention: RETURNING returns 0 rows → returns nil, caller skips probe.
        # - Crashed holder: lock row stays until expires_at < now(), then next caller wins.
        # - Release failure: lock auto-expires after lock_timeout_ms milliseconds.
        #
        class RecoveryLockStore
          # A recovery lock must never be born already-expired. expires_at is the
          # mutual-exclusion window (the lock is normally released explicitly after a
          # probe; the TTL is the crash-safety auto-release). With lock_timeout_ms == 0
          # (e.g. cool_off_time: 0) expires_at would equal now(), so a concurrent
          # acquirer's `WHERE expires_at < now()` guard passes immediately and steals
          # the lock — multiple nodes would run the recovery probe in parallel. Floor
          # the TTL at 1ms so expires_at is always in the future at write time.
          MIN_LOCK_TIMEOUT_MS = 1

          def initialize(connection:, lock_timeout_ms:)
            @connection = connection
            @lock_timeout_ms = [lock_timeout_ms.to_i, MIN_LOCK_TIMEOUT_MS].max
          end

          def acquire_lock(light_name)
            token = SecureRandom.uuid
            sql = <<~SQL
              INSERT INTO stoplight_locks (light, token, expires_at)
              VALUES ($1, $2, now() + ($3 || ' milliseconds')::interval)
              ON CONFLICT (light) DO UPDATE
                SET token = EXCLUDED.token, expires_at = EXCLUDED.expires_at
                WHERE stoplight_locks.expires_at < now()
              RETURNING token
            SQL
            result = with_connection { |conn| conn.exec_params(sql, [light_name, token, lock_timeout_ms]) }
            RecoveryLockToken.new(light_name:, token:) if result.ntuples == 1
          end

          def release_lock(recovery_lock_token)
            with_connection do |conn|
              conn.exec_params(
                "SELECT stoplight_release_lock($1,$2)",
                [recovery_lock_token.light_name, recovery_lock_token.token]
              )
            end
          end

          protected

          attr_reader :connection
          attr_reader :lock_timeout_ms

          private

          def with_connection(&block)
            if connection.respond_to?(:with)
              connection.with(&block)
            else
              yield connection
            end
          end
        end
      end
    end
    # steep:ignore:end
  end
end

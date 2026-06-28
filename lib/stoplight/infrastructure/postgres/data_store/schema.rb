# frozen_string_literal: true

module Stoplight
  module Infrastructure
    # steep:ignore:start
    module Postgres
      class DataStore
        module Schema
          SQL = <<~SQL
            CREATE TABLE IF NOT EXISTS stoplight_events (
              light text NOT NULL, metric text NOT NULL,
              event_id text NOT NULL, occurred_at timestamptz NOT NULL,
              PRIMARY KEY (light, metric, event_id)
            );
            CREATE INDEX IF NOT EXISTS idx_stoplight_events_window ON stoplight_events (light, metric, occurred_at);

            CREATE TABLE IF NOT EXISTS stoplight_metadata (
              light text PRIMARY KEY,
              last_error_class text, last_error_message text, last_error_at timestamptz,
              last_success_at timestamptz,
              consecutive_errors integer NOT NULL DEFAULT 0,
              consecutive_successes integer NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS stoplight_recovery_metrics (
              light text PRIMARY KEY,
              last_error_class text, last_error_message text, last_error_at timestamptz,
              last_success_at timestamptz,
              consecutive_errors integer NOT NULL DEFAULT 0,
              consecutive_successes integer NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS stoplight_states (
              light text PRIMARY KEY,
              locked_state text NOT NULL DEFAULT 'unlocked',
              breached_at timestamptz, recovery_scheduled_after timestamptz,
              recovery_started_at timestamptz, recovered_at timestamptz
            );

            CREATE TABLE IF NOT EXISTS stoplight_locks (
              light text PRIMARY KEY, token text NOT NULL, expires_at timestamptz NOT NULL
            );
          SQL

          def self.create!(conn)
            conn.exec(SQL)
            Functions.install!(conn)
          end
        end
      end
    end
    # steep:ignore:end
  end
end

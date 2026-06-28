# frozen_string_literal: true

require "securerandom"
require "time"

module Stoplight
  module Infrastructure
    # steep:ignore:start
    module Postgres
      # PostgreSQL-backed data store. Mirrors the Redis adapter, using raw `pg`.
      # Atomicity comes from installed pgSQL functions (see Functions module), called
      # via exec_params instead of Lua scripts.
      #
      # Clock policy:
      # All time-sensitive request/metric/state operations use the application Ruby clock
      # (so Timecop and cross-node behavior match the memory/Redis adapters).
      # The recovery lock is the one exception: it uses the database clock (`now()`) for
      # TTL expiry, which is self-consistent regardless of application-node clock skew.
      # See RecoveryLockStore for details.
      #
      # @api private
      class DataStore
        TABLE_PREFIX = "stoplight_"

        # Extra seconds of events kept beyond the current window to guard against
        # clock drift between application nodes.
        RETENTION_MARGIN = 10

        # @param connection [PG::Connection, ConnectionPool<PG::Connection>]
        # @param recovery_lock_store [Postgres::DataStore::RecoveryLockStore]
        # @param clock [Stoplight::Domain::_Clock]
        # @param warn_on_clock_skew [Boolean] accepted for parity; no-op (Ruby clock used)
        def initialize(connection:, recovery_lock_store:, clock:, warn_on_clock_skew: true)
          @connection = connection
          @recovery_lock_store = recovery_lock_store
          @clock = clock
          @warn_on_clock_skew = warn_on_clock_skew
        end

        # @return [Array<String>]
        def names
          with_connection do |conn|
            conn.exec(<<~SQL).map { |row| row["light"] }
              SELECT light FROM stoplight_metadata
              UNION SELECT light FROM stoplight_states
              UNION SELECT light FROM stoplight_recovery_metrics
            SQL
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def delete_light(config)
          transaction do |conn|
            %w[events metadata recovery_metrics states locks].each do |suffix|
              conn.exec_params("DELETE FROM #{TABLE_PREFIX}#{suffix} WHERE light = $1", [config.name])
            end
          end
        end

        # @return [String]
        def inspect = "#<#{self.class.name}>"

        # @param config [Stoplight::Domain::Config]
        # @param exception [Exception]
        # @return [void]
        def record_failure(config, exception)
          failure = Domain::Failure.from_error(exception, time: clock.current_time)
          ts = failure.time.iso8601(6)
          windowed = !config.window_size.nil?
          prune_before = windowed ? (clock.current_time - config.window_size - RETENTION_MARGIN).iso8601(6) : nil

          with_connection do |conn|
            conn.exec_params(
              "SELECT stoplight_record_failure($1,$2,$3::timestamptz,$4,$5,$6::boolean,$7::timestamptz)",
              [config.name, SecureRandom.hex(12), ts, failure.error_class, failure.error_message, windowed, prune_before]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def record_success(config)
          ts = clock.current_time.iso8601(6)
          windowed = !config.window_size.nil?
          prune_before = windowed ? (clock.current_time - config.window_size - RETENTION_MARGIN).iso8601(6) : nil

          with_connection do |conn|
            conn.exec_params(
              "SELECT stoplight_record_success($1,$2,$3::timestamptz,$4::boolean,$5::timestamptz)",
              [config.name, SecureRandom.hex(12), ts, windowed, prune_before]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::MetricsSnapshot]
        def get_metrics(config)
          windowed = !config.window_size.nil?
          window_start = windowed ? (clock.current_time - config.window_size).iso8601(6) : nil

          with_connection do |conn|
            row = conn.exec_params(
              "SELECT * FROM stoplight_get_metrics($1,$2::boolean,$3::timestamptz)",
              [config.name, windowed, window_start]
            ).first

            errors = windowed ? row["errors"]&.to_i : nil
            successes = windowed ? row["successes"]&.to_i : nil
            consecutive_errors = row["consecutive_errors"].to_i
            consecutive_successes = row["consecutive_successes"].to_i

            if windowed
              consecutive_errors = [consecutive_errors, errors].min
              consecutive_successes = [consecutive_successes, successes].min
            end

            Domain::MetricsSnapshot.new(
              errors:,
              successes:,
              consecutive_errors:,
              consecutive_successes:,
              last_error: build_last_error(row),
              last_success_at: decode_time(row["last_success_at"])
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def clear_metrics(config)
          transaction do |conn|
            conn.exec_params(
              "DELETE FROM stoplight_events WHERE light = $1 AND metric IN ('errors', 'successes')",
              [config.name]
            )
            conn.exec_params(
              "DELETE FROM stoplight_metadata WHERE light = $1",
              [config.name]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @param exception [Exception]
        # @return [void]
        def record_recovery_probe_failure(config, exception)
          failure = Domain::Failure.from_error(exception, time: clock.current_time)
          ts = failure.time.iso8601(6)

          with_connection do |conn|
            conn.exec_params(
              "SELECT stoplight_record_recovery_probe_failure($1,$2::timestamptz,$3,$4)",
              [config.name, ts, failure.error_class, failure.error_message]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def record_recovery_probe_success(config)
          ts = clock.current_time.iso8601(6)

          with_connection do |conn|
            conn.exec_params(
              "SELECT stoplight_record_recovery_probe_success($1,$2::timestamptz)",
              [config.name, ts]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::MetricsSnapshot]
        def get_recovery_metrics(config)
          with_connection do |conn|
            row = conn.exec_params(
              "SELECT * FROM stoplight_recovery_metrics WHERE light = $1",
              [config.name]
            ).first

            Domain::MetricsSnapshot.new(
              errors: nil,
              successes: nil,
              consecutive_errors: row ? row["consecutive_errors"].to_i : 0,
              consecutive_successes: row ? row["consecutive_successes"].to_i : 0,
              last_error: build_last_error(row),
              last_success_at: decode_time(row && row["last_success_at"])
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [void]
        def clear_recovery_metrics(config)
          with_connection do |conn|
            conn.exec_params(
              "DELETE FROM stoplight_recovery_metrics WHERE light = $1",
              [config.name]
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @param state [String]
        # @return [String]
        def set_state(config, state)
          with_connection do |conn|
            conn.exec_params(<<~SQL, [config.name, state])
              INSERT INTO stoplight_states (light, locked_state) VALUES ($1, $2)
              ON CONFLICT (light) DO UPDATE SET locked_state = EXCLUDED.locked_state
            SQL
          end
          state
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::StateSnapshot]
        def get_state_snapshot(config)
          current_time = clock.current_time

          with_connection do |conn|
            row = conn.exec_params(
              "SELECT * FROM stoplight_states WHERE light = $1",
              [config.name]
            ).first

            if row
              locked_state = row["locked_state"]
              breached_at = decode_time(row["breached_at"])
              recovery_scheduled_after = decode_time(row["recovery_scheduled_after"])
              recovery_started_at = decode_time(row["recovery_started_at"])
            else
              locked_state = Stoplight::State::UNLOCKED
              breached_at = nil
              recovery_scheduled_after = nil
              recovery_started_at = nil
            end

            Domain::StateSnapshot.new(
              time: current_time,
              locked_state:,
              breached_at:,
              recovery_scheduled_after:,
              recovery_started_at:
            )
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @param color [String]
        # @return [Boolean] true if this caller performed the first transition
        def transition_to_color(config, color)
          case color
          when Color::GREEN
            transition_to_green(config)
          when Color::YELLOW
            transition_to_yellow(config)
          when Color::RED
            transition_to_red(config)
          else
            raise ArgumentError, "Invalid color: #{color}"
          end
        end

        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken, nil]
        def acquire_recovery_lock(config)
          recovery_lock_store.acquire_lock(config.name)
        end

        # @param lock [Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken]
        # @return [void]
        def release_recovery_lock(lock)
          recovery_lock_store.release_lock(lock)
        end

        private

        attr_reader :connection
        attr_reader :recovery_lock_store
        attr_reader :clock

        # Yields a usable PG connection. Supports either a bare PG::Connection or a
        # ConnectionPool<PG::Connection> (checks one out for the block's duration).
        def with_connection(&block)
          if connection.respond_to?(:with)
            connection.with(&block)
          else
            yield connection
          end
        end

        # Yields a connection inside a transaction. Works with both bare PG::Connection
        # and ConnectionPool<PG::Connection> via with_connection.
        def transaction
          with_connection { |conn| conn.transaction { |tx| yield tx } }
        end

        def build_last_error(row)
          return nil unless row && row["last_error_class"]

          Domain::Failure.new(
            row["last_error_class"],
            row["last_error_message"],
            decode_time(row["last_error_at"])
          )
        end

        # Result columns arrive as Strings under the default text protocol, but as
        # already-typed objects (Time, true/false) when the supplied connection has a
        # type map for results (e.g. a connection borrowed from ActiveRecord). Decode
        # defensively so the adapter is correct regardless of the connection's type map.
        def decode_time(value)
          case value
          when nil then nil
          when Time then value
          else Time.parse(value.to_s)
          end
        end

        def decode_bool(value)
          value == true || value == "t"
        end

        # Transitions to RED state. First writer wins via pgSQL function.
        # @return [Boolean] true if this caller set breached_at for the first time
        def transition_to_red(config)
          ct = clock.current_time
          with_connection do |conn|
            result = conn.exec_params(
              "SELECT stoplight_transition_to_red($1,$2::timestamptz,$3::timestamptz)",
              [config.name, ct.iso8601(6), (ct + config.cool_off_time).iso8601(6)]
            )
            decode_bool(result.first["stoplight_transition_to_red"])
          end
        end

        # Transitions to GREEN state. Guard: recovered_at IS NULL.
        # @return [Boolean] true if this caller set recovered_at for the first time
        def transition_to_green(config)
          ct = clock.current_time
          with_connection do |conn|
            result = conn.exec_params(
              "SELECT stoplight_transition_to_green($1,$2::timestamptz)",
              [config.name, ct.iso8601(6)]
            )
            decode_bool(result.first["stoplight_transition_to_green"])
          end
        end

        # Transitions to YELLOW state. Guard: recovery_started_at IS NULL.
        # @return [Boolean] true if this caller set recovery_started_at for the first time
        def transition_to_yellow(config)
          ct = clock.current_time
          with_connection do |conn|
            result = conn.exec_params(
              "SELECT stoplight_transition_to_yellow($1,$2::timestamptz)",
              [config.name, ct.iso8601(6)]
            )
            decode_bool(result.first["stoplight_transition_to_yellow"])
          end
        end
      end
      # steep:ignore:end
    end
  end
end

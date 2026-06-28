# frozen_string_literal: true

require "connection_pool"
require_relative "../data_store/metrics"
require_relative "../data_store/recovery_metrics"

RSpec.describe Stoplight::Infrastructure::Postgres::DataStore, :postgres do
  let(:connection_pool) { ConnectionPool.new(size: 60, timeout: 5) { PG.connect(STOPLIGHT_POSTGRES_URL) } }

  subject(:data_store) do
    described_class.new(
      connection: connection_pool,
      recovery_lock_store: Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockStore.new(
        connection: connection_pool, lock_timeout_ms: 60_000
      ),
      clock: Stoplight::Infrastructure::SystemClock.new
    )
  end

  after { connection_pool.shutdown { |c| c.close } }

  let(:config) { instance_double(Stoplight::Domain::Config, name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:window_size) { 60 }
  let(:cool_off_time) { 60 }

  include_examples "Stoplight::Domain::DataStore#get_metrics"

  it_behaves_like "Stoplight::Domain::DataStore#names"

  include_examples "Stoplight::Domain::DataStore#get_recovery_metrics" do
    def get_metrics = data_store.get_recovery_metrics(config)
    def record_success = data_store.record_recovery_probe_success(config)
    def record_failure(error) = data_store.record_recovery_probe_failure(config, error)
  end

  it_behaves_like "Stoplight::Domain::DataStore#set_state" do
    def set_state(state) = data_store.set_state(config, state)
    def state_snapshot = data_store.get_state_snapshot(config)
    def clear = data_store.delete_light(config)
  end

  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color" do
    def transition_to_color(color) = data_store.transition_to_color(config, color)
    def state_snapshot = data_store.get_state_snapshot(config)
    def clear = data_store.delete_light(config)
  end

  describe "#get_state_snapshot" do
    it "returns UNLOCKED locked_state for an unseen light" do
      snapshot = data_store.get_state_snapshot(config)

      expect(snapshot.locked_state).to eq(Stoplight::State::UNLOCKED)
    end

    it "returns nil timestamps for an unseen light" do
      snapshot = data_store.get_state_snapshot(config)

      expect(snapshot.breached_at).to be_nil
      expect(snapshot.recovery_scheduled_after).to be_nil
      expect(snapshot.recovery_started_at).to be_nil
    end
  end

  describe "#get_recovery_metrics" do
    it "returns nil for errors and successes (no sliding window for recovery)" do
      snapshot = data_store.get_recovery_metrics(config)

      expect(snapshot.errors).to be_nil
      expect(snapshot.successes).to be_nil
    end

    it "returns zeros for consecutive counters when no events have been recorded" do
      snapshot = data_store.get_recovery_metrics(config)

      expect(snapshot.consecutive_errors).to eq(0)
      expect(snapshot.consecutive_successes).to eq(0)
    end

    it "returns nil for last_error and last_success_at when no events have been recorded" do
      snapshot = data_store.get_recovery_metrics(config)

      expect(snapshot.last_error).to be_nil
      expect(snapshot.last_success_at).to be_nil
    end
  end

  describe "#record_recovery_probe_failure then #record_recovery_probe_success" do
    it "resets consecutive_errors to 0 and sets consecutive_successes to 1 after a success following a failure" do
      data_store.record_recovery_probe_failure(config, StandardError.new("probe failed"))
      data_store.record_recovery_probe_success(config)

      snapshot = data_store.get_recovery_metrics(config)

      expect(snapshot.consecutive_errors).to eq(0)
      expect(snapshot.consecutive_successes).to eq(1)
    end
  end

  describe "#clear_recovery_metrics" do
    it "resets consecutive_successes to 0 after recording a success" do
      data_store.record_recovery_probe_success(config)
      expect(data_store.get_recovery_metrics(config).consecutive_successes).to eq(1)

      data_store.clear_recovery_metrics(config)

      snapshot = data_store.get_recovery_metrics(config)
      expect(snapshot.consecutive_successes).to eq(0)
      expect(snapshot.consecutive_errors).to eq(0)
      expect(snapshot.last_error).to be_nil
      expect(snapshot.last_success_at).to be_nil
    end

    it "is a no-op when no recovery metrics have been recorded" do
      expect { data_store.clear_recovery_metrics(config) }.not_to raise_error
    end
  end

  describe "#names" do
    it "returns an empty array when no lights exist in any table" do
      result = data_store.names

      expect(result).to eq([])
    end

    it "returns a light name after inserting a row into stoplight_metadata" do
      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        ["foo"]
      )

      result = data_store.names

      expect(result).to include("foo")
    end

    it "unions across metadata, states, and recovery_metrics without duplicating lights present in multiple tables" do
      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        ["shared-light"]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_states (light) VALUES ($1)",
        ["shared-light"]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_recovery_metrics (light) VALUES ($1)",
        ["shared-light"]
      )

      result = data_store.names

      expect(result.count("shared-light")).to eq(1)
    end

    it "returns lights present only in stoplight_states" do
      pg_connection.exec_params(
        "INSERT INTO stoplight_states (light) VALUES ($1)",
        ["states-only"]
      )

      result = data_store.names

      expect(result).to include("states-only")
    end

    it "returns lights present only in stoplight_recovery_metrics" do
      pg_connection.exec_params(
        "INSERT INTO stoplight_recovery_metrics (light) VALUES ($1)",
        ["recovery-only"]
      )

      result = data_store.names

      expect(result).to include("recovery-only")
    end

    it "handles a light name containing colons (URL-like)" do
      url_light = "http://api.example.com/x"
      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        [url_light]
      )

      result = data_store.names

      expect(result).to include(url_light)
    end
  end

  describe "#record_failure / #record_success / #get_metrics" do
    it "counts 3 failures and 2 successes correctly" do
      3.times { data_store.record_failure(config, StandardError.new("boom")) }
      2.times { data_store.record_success(config) }

      snapshot = data_store.get_metrics(config)

      expect(snapshot.errors).to eq(3)
      expect(snapshot.successes).to eq(2)
    end
  end

  describe "#clear_metrics" do
    it "resets all metrics after recording" do
      data_store.record_failure(config, StandardError.new("boom"))
      data_store.record_success(config)

      data_store.clear_metrics(config)

      snapshot = data_store.get_metrics(config)
      expect(snapshot.errors).to eq(0)
      expect(snapshot.successes).to eq(0)
      expect(snapshot.consecutive_errors).to eq(0)
      expect(snapshot.consecutive_successes).to eq(0)
      expect(snapshot.last_error).to be_nil
    end
  end

  describe "#delete_light" do
    it "removes the light's rows from all five tables" do
      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        [name]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_states (light) VALUES ($1)",
        [name]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_recovery_metrics (light) VALUES ($1)",
        [name]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_events (light, metric, event_id, occurred_at) VALUES ($1, $2, $3, now())",
        [name, "errors", "evt-1"]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_locks (light, token, expires_at) VALUES ($1, $2, now() + interval '1 hour')",
        [name, "token-abc"]
      )

      data_store.delete_light(config)

      %w[metadata states recovery_metrics events locks].each do |table|
        result = pg_connection.exec_params(
          "SELECT COUNT(*) FROM stoplight_#{table} WHERE light = $1",
          [name]
        )
        expect(result[0]["count"].to_i).to eq(0), "Expected 0 rows in stoplight_#{table} after delete_light"
      end
    end

    it "does not remove rows for other lights" do
      other_light = "other-#{name}"

      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        [name]
      )
      pg_connection.exec_params(
        "INSERT INTO stoplight_metadata (light) VALUES ($1)",
        [other_light]
      )

      data_store.delete_light(config)

      result = pg_connection.exec_params(
        "SELECT COUNT(*) FROM stoplight_metadata WHERE light = $1",
        [other_light]
      )
      expect(result[0]["count"].to_i).to eq(1)
    end

    it "is a no-op when the light does not exist in any table" do
      expect { data_store.delete_light(config) }.not_to raise_error
    end
  end

  describe "#inspect" do
    it "returns a string identifying the class" do
      expect(data_store.inspect).to eq("#<Stoplight::Infrastructure::Postgres::DataStore>")
    end
  end

  describe "#acquire_recovery_lock" do
    it "returns a token whose light_name equals config.name" do
      token = data_store.acquire_recovery_lock(config)

      expect(token).not_to be_nil
      expect(token.light_name).to eq(config.name)
    end

    it "returns nil when a lock is already held for the same light" do
      first_token = data_store.acquire_recovery_lock(config)
      expect(first_token).not_to be_nil

      second_attempt = data_store.acquire_recovery_lock(config)

      expect(second_attempt).to be_nil
    end
  end

  describe "#release_recovery_lock" do
    it "allows acquire_recovery_lock to succeed again after releasing the lock" do
      first_token = data_store.acquire_recovery_lock(config)
      expect(first_token).not_to be_nil

      data_store.release_recovery_lock(first_token)

      second_token = data_store.acquire_recovery_lock(config)
      expect(second_token).not_to be_nil
      expect(second_token.light_name).to eq(config.name)
    end
  end

  describe "#record_failure last_error newest-wins guard" do
    it "keeps the newer failure when an older failure is recorded afterward" do
      newer = StandardError.new("newer")
      older = StandardError.new("older")
      base = Time.now

      Timecop.freeze(base + 30) { data_store.record_failure(config, newer) }
      Timecop.freeze(base) { data_store.record_failure(config, older) }

      snapshot = Timecop.freeze(base + 60) { data_store.get_metrics(config) }

      expect(snapshot.last_error.error_message).to eq("newer")
      expect(snapshot.last_error.time).to be_within(0.000001).of(base + 30)
    end
  end

  describe "#record_recovery_probe_failure last_error newest-wins guard" do
    it "keeps the newer failure when an older probe failure is recorded afterward" do
      newer = StandardError.new("newer probe")
      older = StandardError.new("older probe")
      base = Time.now

      Timecop.freeze(base + 30) { data_store.record_recovery_probe_failure(config, newer) }
      Timecop.freeze(base) { data_store.record_recovery_probe_failure(config, older) }

      snapshot = data_store.get_recovery_metrics(config)

      expect(snapshot.last_error.error_message).to eq("newer probe")
      expect(snapshot.last_error.time).to be_within(0.000001).of(base + 30)
    end
  end

  context "when not windowed (window_size: nil)" do
    let(:window_size) { nil }

    describe "#record_failure + #get_metrics" do
      it "returns nil for errors and successes (no event window)" do
        data_store.record_failure(config, StandardError.new("e1"))
        data_store.record_failure(config, StandardError.new("e2"))

        snapshot = data_store.get_metrics(config)

        expect(snapshot.errors).to be_nil
        expect(snapshot.successes).to be_nil
      end

      it "accumulates consecutive_errors as raw counter (not clamped to a window)" do
        data_store.record_failure(config, StandardError.new("e1"))
        data_store.record_failure(config, StandardError.new("e2"))

        snapshot = data_store.get_metrics(config)

        expect(snapshot.consecutive_errors).to eq(2)
      end

      it "returns a Domain::Failure last_error with the error message" do
        error = StandardError.new("non-windowed error")
        data_store.record_failure(config, error)

        snapshot = data_store.get_metrics(config)

        expect(snapshot.last_error).to be_a(Stoplight::Domain::Failure)
        expect(snapshot.last_error.error_message).to eq("non-windowed error")
      end
    end

    describe "#record_success after failures + #get_metrics" do
      it "resets consecutive_errors to 0 and sets consecutive_successes to 1" do
        data_store.record_failure(config, StandardError.new("e1"))
        data_store.record_failure(config, StandardError.new("e2"))
        data_store.record_success(config)

        snapshot = data_store.get_metrics(config)

        expect(snapshot.consecutive_successes).to eq(1)
        expect(snapshot.consecutive_errors).to eq(0)
      end

      it "keeps errors and successes nil after a success" do
        data_store.record_failure(config, StandardError.new("e1"))
        data_store.record_success(config)

        snapshot = data_store.get_metrics(config)

        expect(snapshot.errors).to be_nil
        expect(snapshot.successes).to be_nil
      end
    end

    describe "no events written for a non-windowed light" do
      it "writes zero rows to stoplight_events after record_failure" do
        data_store.record_failure(config, StandardError.new("e1"))

        count = pg_connection.exec_params(
          "SELECT count(*) FROM stoplight_events WHERE light=$1",
          [name]
        ).first["count"].to_i

        expect(count).to eq(0)
      end

      it "writes zero rows to stoplight_events after record_success" do
        data_store.record_failure(config, StandardError.new("e1"))
        data_store.record_success(config)

        count = pg_connection.exec_params(
          "SELECT count(*) FROM stoplight_events WHERE light=$1",
          [name]
        ).first["count"].to_i

        expect(count).to eq(0)
      end
    end

    describe "#get_recovery_metrics with non-windowed config" do
      it "returns nil for errors and successes" do
        data_store.record_recovery_probe_failure(config, StandardError.new("probe"))

        snapshot = data_store.get_recovery_metrics(config)

        expect(snapshot.errors).to be_nil
        expect(snapshot.successes).to be_nil
      end

      it "tracks consecutive counters correctly" do
        data_store.record_recovery_probe_failure(config, StandardError.new("p1"))
        data_store.record_recovery_probe_failure(config, StandardError.new("p2"))

        snapshot = data_store.get_recovery_metrics(config)

        expect(snapshot.consecutive_errors).to eq(2)
      end

      it "resets consecutive_errors after a recovery probe success" do
        data_store.record_recovery_probe_failure(config, StandardError.new("p1"))
        data_store.record_recovery_probe_success(config)

        snapshot = data_store.get_recovery_metrics(config)

        expect(snapshot.consecutive_errors).to eq(0)
        expect(snapshot.consecutive_successes).to eq(1)
      end
    end
  end
end

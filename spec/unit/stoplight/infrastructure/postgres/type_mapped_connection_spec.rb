# frozen_string_literal: true

# A connection borrowed from ActiveRecord (or any caller that configures a
# type map) returns already-decoded Ruby objects — Time for timestamptz,
# true/false for boolean — instead of Strings. The adapter must decode results
# defensively so it works with such connections, not only with the default
# text protocol.
RSpec.describe Stoplight::Infrastructure::Postgres::DataStore, ":postgres type-mapped connection", :postgres do
  subject(:data_store) do
    described_class.new(
      connection: typed_connection,
      recovery_lock_store: Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockStore.new(
        connection: typed_connection, lock_timeout_ms: 60_000
      ),
      clock: Stoplight::Infrastructure::SystemClock.new
    )
  end

  # Connection that decodes results into typed Ruby objects (timestamptz -> Time,
  # bool -> true/false), mimicking an ActiveRecord-derived connection.
  let(:typed_connection) do
    conn = PG.connect(STOPLIGHT_POSTGRES_URL)
    conn.type_map_for_results = PG::BasicTypeMapForResults.new(conn)
    conn
  end

  after { typed_connection.close }

  let(:config) { instance_double(Stoplight::Domain::Config, name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:window_size) { 60 }
  let(:cool_off_time) { 60 }
  let(:error) { StandardError.new("boom") }

  it "reads metrics (Time-typed last_error_at) without raising" do
    data_store.record_failure(config, error)
    snapshot = data_store.get_metrics(config)

    expect(snapshot.consecutive_errors).to eq(1)
    expect(snapshot.last_error.error_message).to eq("boom")
    expect(snapshot.last_error.time).to be_a(Time)
  end

  it "reads recovery metrics without raising" do
    data_store.record_recovery_probe_success(config)
    expect(data_store.get_recovery_metrics(config).consecutive_successes).to eq(1)
  end

  it "decodes boolean transition result (first-writer-wins still works)" do
    expect(data_store.transition_to_color(config, Stoplight::Color::RED)).to be(true)
    expect(data_store.transition_to_color(config, Stoplight::Color::RED)).to be(false)
  end

  it "reads a state snapshot with Time-typed timestamps" do
    data_store.transition_to_color(config, Stoplight::Color::RED)
    snapshot = data_store.get_state_snapshot(config)

    expect(snapshot.breached_at).to be_a(Time)
    expect(snapshot.recovery_scheduled_after).to be_a(Time)
  end
end

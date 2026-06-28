# frozen_string_literal: true

require "rantly/rspec_extensions"
require "spec_helper"
require "connection_pool"

# Property test for Postgres DataStore window counting.
#
# Approach: direct SQL insert via pg_connection.
# Rather than driving time with Timecop+record_failure (which would require one
# Timecop.freeze block per event and proved flakey under concurrent TRUNCATE
# interactions), we insert rows directly into stoplight_events with explicit
# occurred_at timestamps computed as (base - offset). This gives deterministic,
# sub-second precision and avoids Timecop state leaking across property
# iterations. After inserting, we freeze time at `base` and assert that
# get_metrics.errors equals the count of offsets strictly less than window_size.
RSpec.describe "Stoplight::Infrastructure::Postgres::DataStore#get_metrics window counting", :postgres do
  let(:connection_pool) { ConnectionPool.new(size: 5, timeout: 5) { PG.connect(STOPLIGHT_POSTGRES_URL) } }
  let(:light_name) { "property-test-light" }

  subject(:data_store) do
    Stoplight::Infrastructure::Postgres::DataStore.new(
      connection: connection_pool,
      recovery_lock_store: Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockStore.new(
        connection: connection_pool, lock_timeout_ms: 60_000
      ),
      clock: Stoplight::Infrastructure::SystemClock.new
    )
  end

  after { connection_pool.shutdown { |c| c.close } }

  let(:config) { instance_double(Stoplight::Domain::Config, name: light_name, window_size:, cool_off_time: 60) }
  let(:window_size) { 60 } # overridden per property iteration

  it "counts only errors whose occurred_at falls within the window" do
    property_of {
      window_size = range(10, 3600)
      n_events = range(0, 20)
      # Each offset is a number of seconds before base; may be inside or outside the window.
      offsets = Array.new(n_events) { range(0, window_size * 2) }
      [window_size, offsets]
    }.check do |prop_window_size, offsets|
      base = Time.now

      # Clear only this light's rows between property iterations so the
      # per-example TRUNCATE in database_cleaner_postgres covers the first
      # iteration and we handle the rest manually.
      pg_connection.exec_params(
        "DELETE FROM stoplight_events WHERE light = $1",
        [light_name]
      )

      # Insert events directly with computed timestamps for deterministic control.
      offsets.each_with_index do |offset, idx|
        occurred_at = base - offset
        pg_connection.exec_params(
          "INSERT INTO stoplight_events (light, metric, event_id, occurred_at) VALUES ($1, $2, $3, $4)",
          [light_name, "errors", "evt-#{idx}-#{offset}", occurred_at.iso8601(6)]
        )
      end

      # Lower bound is inclusive: an event at occurred_at == window_start
      # (offset == window_size) is counted, matching the memory adapter's
      # `timestamp >= window_start` semantics.
      expected_errors = offsets.count { |offset| offset <= prop_window_size }

      config_for_iteration = instance_double(
        Stoplight::Domain::Config,
        name: light_name,
        window_size: prop_window_size,
        cool_off_time: 60
      )

      snapshot = Timecop.freeze(base) { data_store.get_metrics(config_for_iteration) }

      expect(snapshot.errors).to eq(expected_errors)
    end
  end

  it "returns nil errors/successes and raw consecutive_errors when window_size is nil" do
    nil_config = instance_double(
      Stoplight::Domain::Config,
      name: light_name,
      window_size: nil,
      cool_off_time: 60
    )

    3.times { data_store.record_failure(nil_config, StandardError.new("non-windowed")) }

    snapshot = data_store.get_metrics(nil_config)

    expect(snapshot.errors).to be_nil
    expect(snapshot.successes).to be_nil
    expect(snapshot.consecutive_errors).to eq(3)
  end
end

# frozen_string_literal: true

require "pg"

STOPLIGHT_POSTGRES_URL = ENV.fetch("STOPLIGHT_POSTGRES_URL", "postgres://localhost:5432/stoplight_test")

RSpec.shared_context :postgres, :postgres do
  let(:pg_connection) { PG.connect(STOPLIGHT_POSTGRES_URL) }

  before(:all) do
    conn = PG.connect(STOPLIGHT_POSTGRES_URL)
    Stoplight::Infrastructure::Postgres::DataStore::Schema.create!(conn)
    conn.close
  end

  before do
    pg_connection.exec(
      "TRUNCATE stoplight_events, stoplight_metadata, stoplight_recovery_metrics, stoplight_states, stoplight_locks"
    )
  end

  after do
    pg_connection.close
  end
end

RSpec.configure do |config|
  config.include_context :postgres, include_shared: true
end

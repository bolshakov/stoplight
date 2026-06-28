# frozen_string_literal: true

require "concurrent"

RSpec.describe Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockStore, :postgres do
  subject(:store) { described_class.new(connection: pg_connection, lock_timeout_ms: lock_timeout_ms) }

  let(:lock_timeout_ms) { 60_000 }
  let(:light_name) { SecureRandom.uuid }

  describe "#acquire_lock" do
    it "returns a token with the correct light_name and a non-nil token string" do
      token = store.acquire_lock(light_name)

      expect(token).to be_a(Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken)
      expect(token.light_name).to eq(light_name)
      expect(token.token).not_to be_nil
    end

    it "returns nil for the same light while the first lock is unexpired" do
      first = store.acquire_lock(light_name)
      expect(first).not_to be_nil

      second = store.acquire_lock(light_name)
      expect(second).to be_nil
    end

    context "when lock_timeout_ms is 0 (e.g. cool_off_time: 0)" do
      let(:lock_timeout_ms) { 0 }

      it "does not create an already-expired lock (single-prober guarantee holds)" do
        first = store.acquire_lock(light_name)
        expect(first).not_to be_nil

        # Without the TTL floor, expires_at == now() and this second call would
        # steal the lock immediately, letting multiple nodes probe in parallel.
        second = store.acquire_lock(light_name)
        expect(second).to be_nil
      end
    end

    it "acquires a lock for a different light independently" do
      other_light = SecureRandom.uuid
      store.acquire_lock(light_name)

      other_token = store.acquire_lock(other_light)
      expect(other_token).to be_a(Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken)
      expect(other_token.light_name).to eq(other_light)
    end
  end

  describe "#release_lock" do
    it "allows a new acquire after the lock is released" do
      first = store.acquire_lock(light_name)
      expect(first).not_to be_nil

      store.release_lock(first)

      second = store.acquire_lock(light_name)
      expect(second).to be_a(Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken)
      expect(second.token).not_to eq(first.token)
    end
  end

  describe "lock expiry" do
    subject(:short_store) { described_class.new(connection: pg_connection, lock_timeout_ms: 200) }

    it "allows re-acquisition after the lock timeout expires" do
      first = short_store.acquire_lock(light_name)
      expect(first).not_to be_nil

      # Second attempt before expiry must fail
      second = short_store.acquire_lock(light_name)
      expect(second).to be_nil

      # Wait long enough for the lock to expire
      sleep 0.3

      # Third attempt after expiry must succeed
      third = short_store.acquire_lock(light_name)
      expect(third).to be_a(Stoplight::Infrastructure::Postgres::DataStore::RecoveryLockToken)
    end
  end

  describe "thread safety" do
    let(:thread_count) { 50 }
    let(:barrier) { Concurrent::CyclicBarrier.new(thread_count) }
    let(:winners) { Concurrent::Array.new }

    it "allows exactly one winner across 50 concurrent threads racing for the same lock" do
      threads = thread_count.times.map do
        Thread.new do
          conn = PG.connect(STOPLIGHT_POSTGRES_URL)
          begin
            thread_store = described_class.new(connection: conn, lock_timeout_ms: lock_timeout_ms)
            barrier.wait
            result = thread_store.acquire_lock("contended")
            winners << result unless result.nil?
          ensure
            conn.close
          end
        end
      end

      threads.each(&:join)

      expect(winners.size).to eq(1)
    end
  end
end

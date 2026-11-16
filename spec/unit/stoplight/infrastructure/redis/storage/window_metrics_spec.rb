# frozen_string_literal: true

require_relative "../../data_store/window_metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::WindowMetrics, :redis do
  subject(:metrics) { described_class.new(scripting:, redis:, config:, clock:, key_space:) }

  let(:key_space) { Stoplight::DataStore::Redis.key_space.join(SecureRandom.uuid) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:config) { instance_double(Stoplight::Domain::Config, window_size:) }
  let(:scripting) do
    Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:, scripts_path: Stoplight::TimeTravel.scripts_path)
  end
  let(:window_size) { 300 }

  it_behaves_like "a window metrics snapshot" do
    def metrics_snapshot = metrics.metrics_snapshot
    def record_failure(error) = metrics.record_failure(error)
    def record_success = metrics.record_success
    def clear = metrics.clear
  end

  describe "#record_failure" do
    it "fetches the resulting snapshot in a single round trip" do
      expect(scripting).to receive(:call).once.and_call_original

      metrics.record_failure(StandardError.new)
    end
  end

  describe "bucket eviction" do
    it "does not call HINCRBY with -0 on total_failures when evicting buckets with only successes" do
      Stoplight::TimeTravel.freeze(Time.now - window_size - 10) do
        metrics.record_success
      end

      metrics.record_success

      has_total_failures = redis.with { |client| client.hexists(key_space.join("window_metrics"), "total_failures") }
      expect(has_total_failures).to be(false)
    end

    it "does not call HINCRBY with -0 on total_successes when evicting buckets with only failures" do
      Stoplight::TimeTravel.freeze(Time.now - window_size - 10) do
        metrics.record_failure(StandardError.new)
      end

      metrics.record_failure(StandardError.new)

      has_total_successes = redis.with { |client| client.hexists(key_space.join("window_metrics"), "total_successes") }
      expect(has_total_successes).to be(false)
    end
  end
end

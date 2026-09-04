# frozen_string_literal: true

require_relative "../../data_store/metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::UnboundedMetrics, :redis do
  subject(:unbounded_metrics) { described_class.new(scripting:, redis:, key_space:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:key_space) { Stoplight::DataStore::Redis.key_space.join(SecureRandom.uuid) }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }

  it_behaves_like "a metrics snapshot" do
    def metrics_snapshot = unbounded_metrics.metrics_snapshot
    def record_failure(error) = unbounded_metrics.record_failure(error)
    def record_success = unbounded_metrics.record_success
    def clear = unbounded_metrics.clear
  end

  describe "#record_failure" do
    it "sets a TTL on the metrics key when it is the first ever failure" do
      unbounded_metrics.record_failure(StandardError.new)

      ttl = redis.with { |client| client.ttl(key_space.join(:metrics)) }
      expect(ttl).to be_positive
    end

    it "keeps the TTL on the metrics key for a subsequent out-of-order failure" do
      unbounded_metrics.record_failure(StandardError.new)

      Timecop.freeze(Time.now - 30) do
        unbounded_metrics.record_failure(StandardError.new)
      end

      ttl = redis.with { |client| client.ttl(key_space.join("metrics")) }
      expect(ttl).to be_positive
    end

    it "fetches the resulting snapshot in a single round trip" do
      expect(scripting).to receive(:call).once.and_call_original

      unbounded_metrics.record_failure(StandardError.new)
    end
  end

  describe "#clear" do
    it "removes every field #record_failure writes, leaving no residual hash fields" do
      unbounded_metrics.record_failure(StandardError.new)

      unbounded_metrics.clear

      fields = redis.with { |client| client.hkeys(key_space.join(:metrics)) }
      expect(fields).to be_empty
    end
  end
end

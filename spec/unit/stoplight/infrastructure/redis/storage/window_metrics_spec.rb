# frozen_string_literal: true

require_relative "../../data_store/window_metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::WindowMetrics, :redis do
  subject(:metrics) { described_class.new(scripting:, redis:, config:, clock:, key_space:) }

  let(:key_space) { Stoplight::DataStore::Redis.key_space.join(SecureRandom.uuid) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:config) { instance_double(Stoplight::Domain::Config, window_size:) }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }
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
end

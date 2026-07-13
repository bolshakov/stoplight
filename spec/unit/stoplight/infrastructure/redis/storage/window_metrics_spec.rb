# frozen_string_literal: true

require_relative "../../data_store/window_metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::WindowMetrics, :redis do
  subject(:metrics) { described_class.new(scripting:, redis:, config:, clock:, key_space:) }

  let(:key_space) { Stoplight::Infrastructure::Redis::Storage::KeySpace.build(light_name:, system_name:) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:config) { instance_double(Stoplight::Domain::Config, window_size:) }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }
  let(:window_size) { 300 }

  let(:light_name) { SecureRandom.uuid }
  let(:system_name) { SecureRandom.uuid }

  it_behaves_like "a window metrics snapshot" do
    def metrics_snapshot = metrics.metrics_snapshot
    def record_failure(error) = metrics.record_failure(error)
    def record_success = metrics.record_success
  end

  describe "#record_success" do
    it "fetches the resulting snapshot in a single round trip" do
      expect(scripting).to receive(:call).once.and_call_original

      metrics.record_success
    end
  end

  describe "#record_failure" do
    it "fetches the resulting snapshot in a single round trip" do
      expect(scripting).to receive(:call).once.and_call_original

      metrics.record_failure(StandardError.new)
    end
  end

  describe "#buckets_for_window" do
    subject(:buckets) { metrics.buckets_for_window(metric:, window_end:) }

    let(:metric) { "failures" }

    context "when window size is smaller than the bucket size" do
      let(:window_end) { Time.at(1696156496) }
      let(:window_size) { 1000 } # Smaller than BUCKET_SIZE (3600)

      it "returns a single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696154400"
        )
      end
    end

    context "when window size spans multiple buckets" do
      let(:window_end) { Time.at(1696154400) }
      let(:window_size) { 14400 } # Spans 4 buckets (3600s each)

      it "returns all bucket keys within the window" do
        is_expected.to contain_exactly(
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696140000",
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696143600",
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696147200",
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696150800"
        )
      end
    end

    context "when window size is exactly one bucket size" do
      let(:window_end) { Time.at(1696154400) }
      let(:window_size) { 3600 } # Exactly one bucket size

      it "returns the single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:#{key_space.system_id}:{#{key_space.light_id}}:window_metrics:failures:1696150800"
        )
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../../data_store/metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Redis::Storage::UnboundedMetrics, :redis do
  subject(:unbounded_metrics) { described_class.new(scripting:, redis:, key_space:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:key_space) { Stoplight::Infrastructure::Redis::Storage::KeySpace.build(light_name:, system_name:) }
  let(:scripting) { Stoplight::Infrastructure::Redis::Storage::Scripting.new(redis:) }

  let(:light_name) { SecureRandom.uuid }
  let(:system_name) { SecureRandom.uuid }

  it_behaves_like "a metrics snapshot" do
    def metrics_snapshot = unbounded_metrics.metrics_snapshot
    def record_failure(error) = unbounded_metrics.record_failure(error)
    def record_success = unbounded_metrics.record_success
  end
end

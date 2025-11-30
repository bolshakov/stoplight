# frozen_string_literal: true

require_relative "../../data_store/metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Storage::Redis::UnboundedMetrics, :redis do
  subject(:unbounded_metrics) { described_class.new(scripting:, redis:, key_space:) }

  let(:key_space) { Stoplight::Infrastructure::Storage::Redis::KeySpace.build(light_name:, system_name:) }
  let(:scripting) { Stoplight::Infrastructure::Storage::Redis::Scripting.new(redis:) }

  let(:light_name) { SecureRandom.uuid }
  let(:system_name) { SecureRandom.uuid }

  def metrics_snapshot = unbounded_metrics.metrics_snapshot
  def record_failure(error) = unbounded_metrics.record_failure(error)
  def record_success = unbounded_metrics.record_success

  it_behaves_like "a metrics snapshot"
end

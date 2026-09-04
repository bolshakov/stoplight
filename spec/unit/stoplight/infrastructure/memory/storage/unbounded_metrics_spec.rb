# frozen_string_literal: true

require_relative "../../data_store/metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Memory::Storage::UnboundedMetrics do
  subject(:unbounded_metrics) { described_class.new(clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  it_behaves_like "a metrics snapshot" do
    def metrics_snapshot = unbounded_metrics.metrics_snapshot
    def record_failure(error) = unbounded_metrics.record_failure(error)
    def record_success = unbounded_metrics.record_success
    def clear = unbounded_metrics.clear
  end
end

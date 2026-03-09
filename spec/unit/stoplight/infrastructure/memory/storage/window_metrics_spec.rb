# frozen_string_literal: true

require_relative "../../data_store/window_metrics_snapshot"

RSpec.describe Stoplight::Infrastructure::Memory::Storage::WindowMetrics do
  subject(:metrics) { described_class.new(window_size:, clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:window_size) { 300 }

  it_behaves_like "a window metrics snapshot" do
    def metrics_snapshot = metrics.metrics_snapshot
    def record_failure(error) = metrics.record_failure(error)
    def record_success = metrics.record_success
  end
end

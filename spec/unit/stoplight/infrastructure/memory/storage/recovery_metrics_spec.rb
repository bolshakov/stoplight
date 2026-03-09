# frozen_string_literal: true

require_relative "../../data_store/recovery_metrics"

RSpec.describe Stoplight::Infrastructure::Memory::Storage::RecoveryMetrics do
  subject(:metrics_store) { described_class.new(clock:) }

  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics" do
    def get_metrics = metrics_store.metrics_snapshot
    def record_failure(error) = metrics_store.record_failure(error)
    def record_success = metrics_store.record_success
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::CompatibilityRecoveryMetrics do
  subject(:store) { described_class.new(data_store:, config:) }

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store) { instance_double(NullDataStore) }

  describe "#metrics_snapshot" do
    subject { store.metrics_snapshot }

    let(:metrics) { instance_double(Stoplight::Domain::MetricsSnapshot) }

    it "delegates to data store" do
      expect(data_store).to receive(:get_recovery_metrics).with(config).and_return(metrics)

      expect(store.metrics_snapshot).to eq(metrics)
    end
  end

  describe "#record_success" do
    it "delegates to data store" do
      expect(data_store).to receive(:record_recovery_probe_success).with(config)

      store.record_success
    end
  end

  describe "#record_failure" do
    let(:error) { StandardError.new("Something went wrong") }

    it "delegates to data store" do
      expect(data_store).to receive(:record_recovery_probe_failure).with(config, error)

      store.record_failure(error)
    end
  end

  describe "#clear" do
    it "delegates to data store" do
      expect(data_store).to receive(:clear_recovery_metrics).with(config)

      store.clear
    end
  end
end

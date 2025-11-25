# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::CompatibilityMetrics do
  subject(:store) { described_class.new(data_store:, config:) }

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

  describe "#metrics_snapshot" do
    subject { store.metrics_snapshot }

    let(:metrics) { instance_double(Stoplight::Domain::Metrics) }

    it "delegates to data store" do
      expect(data_store).to receive(:get_metrics).with(config).and_return(metrics)

      expect(store.metrics_snapshot).to eq(metrics)
    end
  end

  describe "#record_success" do
    it "delegates to data store" do
      expect(data_store).to receive(:record_success).with(config)

      store.record_success
    end
  end

  describe "#record_failure" do
    let(:error) { StandardError.new("Something went wrong") }

    it "delegates to data store" do
      expect(data_store).to receive(:record_failure).with(config, error)

      store.record_failure(error)
    end
  end

  describe "#reset" do
    it "delegates to data store" do
      expect(data_store).to receive(:clear_metrics).with(config)

      store.clear
    end
  end
end

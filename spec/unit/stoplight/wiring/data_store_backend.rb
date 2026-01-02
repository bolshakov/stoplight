# frozen_string_literal: true

RSpec.shared_examples Stoplight::Wiring::DataStoreBackend do
  let(:clock) { instance_double(Stoplight::Domain::Clock) }

  describe "#state_store" do
    subject(:state_store) { backend.state_store }

    let(:config) { instance_double(Stoplight::Domain::Config, cool_off_time: 42) }

    it "returns a state store" do
      is_expected.to be_kind_of(Stoplight::Domain::Storage::State)
    end

    it "returns the same instance on repeated calls" do
      expect(backend.state_store).to be(state_store)
    end
  end

  describe "#recovery_lock_store" do
    subject(:recovery_lock_store) { backend.recovery_lock_store }

    let(:config) { instance_double(Stoplight::Domain::Config) }

    it "returns a recovery lock store" do
      is_expected.to be_kind_of(Stoplight::Domain::Storage::RecoveryLock)
    end

    it "returns the same instance on repeated calls" do
      expect(backend.recovery_lock_store).to be(recovery_lock_store)
    end
  end

  describe "#recovery_metrics_store" do
    subject(:recovery_metrics_store) { backend.recovery_metrics_store }

    let(:config) { instance_double(Stoplight::Domain::Config) }

    it "returns a recovery metrics store" do
      is_expected.to be_kind_of(Stoplight::Domain::Storage::Metrics)
    end

    it "returns the same instance on repeated calls" do
      expect(backend.recovery_metrics_store).to be(recovery_metrics_store)
    end
  end

  describe "#windowed_metrics_store" do
    subject(:windowed_metrics_store) { backend.windowed_metrics_store }

    let(:config) { instance_double(Stoplight::Domain::Config, window_size: 42) }

    it "returns a windowed metrics store" do
      is_expected.to be_kind_of(Stoplight::Domain::Storage::Metrics)
    end

    it "returns the same instance on repeated calls" do
      expect(backend.windowed_metrics_store).to be(windowed_metrics_store)
    end
  end

  describe "#unbounded_metrics_store" do
    subject(:unbounded_metrics_store) { backend.unbounded_metrics_store }

    let(:config) { instance_double(Stoplight::Domain::Config, window_size: 42) }

    it "returns a unbounded metrics store" do
      is_expected.to be_kind_of(Stoplight::Domain::Storage::Metrics)
    end

    it "returns the same instance on repeated calls" do
      expect(backend.unbounded_metrics_store).to be(unbounded_metrics_store)
    end
  end
end

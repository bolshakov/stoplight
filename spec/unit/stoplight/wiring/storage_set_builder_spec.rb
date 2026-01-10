# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::StorageSetBuilder do
  let(:builder) { described_class.new(backend:, windowed:) }

  describe "#build" do
    let(:backend) do
      instance_double(Stoplight::Wiring::DataStoreBackend,
        recovery_metrics_store:,
        state_store:,
        recovery_lock_store:,
        windowed_metrics_store:,
        unbounded_metrics_store:)
    end
    let(:recovery_metrics_store) { instance_double(NullMetricsStore) }
    let(:windowed_metrics_store) { instance_double(NullMetricsStore) }
    let(:unbounded_metrics_store) { instance_double(NullMetricsStore) }
    let(:state_store) { instance_double(NullStateStore) }
    let(:recovery_lock_store) { instance_double(NullRecoveryLockStore) }

    context "when windowed" do
      let(:windowed) { true }

      it "builds storage set" do
        expect(builder.build).to have_attributes(
          recovery_metrics_store:,
          state_store:,
          recovery_lock_store:,
          metrics_store: windowed_metrics_store
        )
      end
    end

    context "when not windowed" do
      let(:windowed) { false }

      it "builds storage set" do
        expect(builder.build).to have_attributes(
          recovery_metrics_store:,
          state_store:,
          recovery_lock_store:,
          metrics_store: unbounded_metrics_store
        )
      end
    end
  end
end

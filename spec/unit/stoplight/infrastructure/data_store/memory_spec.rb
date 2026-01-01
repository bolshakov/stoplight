# frozen_string_literal: true

require_relative "recovery_metrics"
require_relative "metrics"

RSpec.describe Stoplight::Infrastructure::DataStore::Memory do
  let(:data_store) { described_class.new(recovery_lock_store:, clock:) }
  let(:recovery_lock_store) { instance_double(described_class::RecoveryLockStore) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  let(:config) { instance_double(Stoplight::Domain::Config, name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:cool_off_time) { 60 }
  let(:window_size) { 60 }

  it_behaves_like "Stoplight::Domain::DataStore"
  it_behaves_like "Stoplight::Domain::DataStore#get_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics" do
    def get_metrics = data_store.get_recovery_metrics(config)
    def record_failure(error) = data_store.record_recovery_probe_failure(config, error)
    def record_success = data_store.record_recovery_probe_success(config)
  end
  it_behaves_like "Stoplight::Domain::DataStore#names"
  it_behaves_like "Stoplight::Domain::DataStore#set_state" do
    def set_state(state) = data_store.set_state(config, state)
    def state_snapshot = data_store.get_state_snapshot(config)
    def clear = data_store.delete_light(config)
  end
  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color" do
    def transition_to_color(color) = data_store.transition_to_color(config, color)
    def state_snapshot = data_store.get_state_snapshot(config)
    def clear = data_store.delete_light(config)
  end

  describe "#acquire_recovery_lock" do
    let(:recovery_lock) { instance_double(described_class::RecoveryLockToken) }

    it "passes control to recovery lock" do
      expect(recovery_lock_store).to receive(:acquire_lock).with(name).and_return(recovery_lock)

      acquired_lock = data_store.acquire_recovery_lock(config)
      expect(acquired_lock).to eq(recovery_lock)
    end
  end

  describe "#release_recovery_lock" do
    let(:recovery_lock) { instance_double(described_class::RecoveryLockToken) }

    it "passes control to recovery lock" do
      expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock)

      data_store.release_recovery_lock(recovery_lock)
    end
  end
end

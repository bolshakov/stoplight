# frozen_string_literal: true

require_relative "recovery_metrics"
require_relative "metrics"

RSpec.describe Stoplight::Infrastructure::DataStore::Memory do
  let(:data_store) { described_class.new(recovery_lock_store:, clock:) }
  let(:recovery_lock_store) { instance_double(described_class::RecoveryLockStore) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:cool_off_time) { 60 }
  let(:window_size) { 60 }

  it_behaves_like "Stoplight::Domain::DataStore"
  it_behaves_like "Stoplight::Domain::DataStore#get_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics"
  it_behaves_like "Stoplight::Domain::DataStore#names"
  it_behaves_like "Stoplight::Domain::DataStore#set_state" do
    def set_state(state) = data_store.set_state(config, state)
    def get_state_snapshot = data_store.get_state_snapshot(config)
  end
  it_behaves_like "Stoplight::Domain::DataStore#transition_to_color"

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

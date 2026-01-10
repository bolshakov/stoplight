# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::CompatibilityRecoveryLock do
  subject(:store) { described_class.new(data_store:, config:) }

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store) { instance_double(NullDataStore) }
  let(:lock_token) { instance_double(NullRecoveryLockToken) }

  describe "#acquire_lock" do
    subject { store.acquire_lock }

    it "delegates to data store" do
      expect(data_store).to receive(:acquire_recovery_lock).with(config).and_return(lock_token)

      is_expected.to eq(lock_token)
    end
  end

  specify "#release_lock" do
    expect(data_store).to receive(:release_recovery_lock).with(lock_token)

    store.release_lock(lock_token)
  end
end

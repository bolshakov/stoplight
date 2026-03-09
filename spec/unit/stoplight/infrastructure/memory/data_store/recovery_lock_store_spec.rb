# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::DataStore::RecoveryLockStore do
  let(:store) { described_class.new }

  let(:data_store) { instance_double(NullDataStore) }
  let(:light_name) { SecureRandom.uuid }

  it "acquires lock and return recovery lock" do
    recovery_lock = store.acquire_lock(light_name)

    expect(recovery_lock).to be_kind_of(Stoplight::Infrastructure::Memory::DataStore::RecoveryLockToken)
  end

  it "cannot acquire a lock that is already acquired" do
    recovery_lock = store.acquire_lock(light_name)
    expect(recovery_lock).not_to be(nil)

    recovery_lock2 = store.acquire_lock(light_name)
    expect(recovery_lock2).to be(nil)
  end

  it "can acquire after release" do
    recovery_lock = store.acquire_lock(light_name)
    expect(recovery_lock).not_to be(nil)
    store.release_lock(recovery_lock)

    recovery_lock2 = store.acquire_lock(light_name)
    expect(recovery_lock2).to be_kind_of(Stoplight::Infrastructure::Memory::DataStore::RecoveryLockToken)
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::Redis::RecoveryLockStore, :redis do
  let(:store) { described_class.new(redis:, lock_timeout:) }

  let(:light_name) { SecureRandom.uuid }
  let(:lock_timeout) { 100 }

  it "acquires lock and return recovery lock" do
    recovery_lock = store.acquire_lock(light_name)

    expect(recovery_lock).to be_kind_of(Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken)
    expect(recovery_lock.light_name).to eq(light_name)
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
    expect(recovery_lock2).to be_kind_of(Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken)
    expect(recovery_lock2.light_name).to eq(light_name)
    expect(recovery_lock2.token).not_to eq(recovery_lock.token)
  end

  it "automatically releases after a timeout" do
    store.acquire_lock(light_name)

    until (recovery_lock = store.acquire_lock(light_name))
      sleep(lock_timeout.fdiv(1000))
    end

    expect(recovery_lock).to be_kind_of(Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken)
  end
end

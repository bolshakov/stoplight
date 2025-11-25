# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::Redis::RecoveryLock, :redis do
  let(:store) { described_class.new(redis:, scripting:, config:) }
  let(:scripting) { Stoplight::Infrastructure::DataStore::Redis::Scripting.new(redis:) }
  let(:config) { instance_double(Stoplight::Domain::Config, name:, cool_off_time_in_milliseconds:) }

  let(:name) { SecureRandom.uuid }
  let(:cool_off_time_in_milliseconds) { 100 }

  it "acquires lock and return recovery lock" do
    recovery_lock = store.acquire_lock

    expect(recovery_lock).to be_kind_of(Stoplight::Infrastructure::Storage::Redis::RecoveryLockToken)
  end

  it "cannot acquire a lock that is already acquired" do
    recovery_lock = store.acquire_lock
    expect(recovery_lock).not_to be(nil)

    recovery_lock2 = store.acquire_lock
    expect(recovery_lock2).to be(nil)
  end

  it "can acquire after release" do
    recovery_lock = store.acquire_lock
    expect(recovery_lock).not_to be(nil)
    store.release_lock(recovery_lock)

    recovery_lock2 = store.acquire_lock
    expect(recovery_lock2).to be_kind_of(Stoplight::Infrastructure::Storage::Redis::RecoveryLockToken)
    expect(recovery_lock2.token).not_to eq(recovery_lock.token)
  end

  it "automatically releases after a timeout" do
    store.acquire_lock

    until (recovery_lock = store.acquire_lock)
      sleep(cool_off_time_in_milliseconds.fdiv(1000))
    end

    expect(recovery_lock).to be_kind_of(Stoplight::Infrastructure::Storage::Redis::RecoveryLockToken)
  end
end

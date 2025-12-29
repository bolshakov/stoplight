# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::Memory::RecoveryLock do
  let(:store) { described_class.new }

  it "does not acquire if lock is already acquired" do
    expect(store.acquire_lock).to be_kind_of(Stoplight::Domain::RecoveryLockToken)
    expect(store.acquire_lock).to eq(nil)
  end

  it "acquires released lock" do
    token = store.acquire_lock
    expect(token).to be_kind_of(Stoplight::Domain::RecoveryLockToken)

    store.release_lock(token)

    expect(store.acquire_lock).not_to eq(nil)
  end

  it "cannot release from a wrong thread token" do
    token_future = Concurrent::Promises.resolvable_future
    release_latch = Concurrent::CountDownLatch.new(1)

    thread = Thread.new do
      token = store.acquire_lock
      token_future.fulfill(token)

      release_latch.wait # It does not release immediately. Wait till test allow to release

      store.release_lock(token)
    end
    token_future.wait # makes sure the lock is acquired

    expect(store.acquire_lock).to eq(nil), "should not acquire lock from another thread"
    expect { store.release_lock(token_future.value) }.to raise_error(ThreadError), "should not release lock from another thread"

    release_latch.count_down # Proceed to release
    thread.join # what the release to finish

    expect(store.acquire_lock).to be_kind_of(Stoplight::Domain::RecoveryLockToken), "should be able to lock if thread dies"
  end
end

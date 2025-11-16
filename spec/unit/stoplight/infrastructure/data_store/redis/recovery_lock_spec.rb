# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::Redis::RecoveryLock, :redis do
  let(:recovery_lock) { described_class.new(redis:, data_store:, lock_timeout:) }

  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:light_name) { SecureRandom.uuid }
  let(:lock_timeout) { 100 }

  describe "#with_lock" do
    it "acquires a lock and yields data store" do
      expect do |block|
        expect(recovery_lock.with_lock(light_name, &block)).to eq(true)
      end.to yield_with_args(data_store)
    end

    it "cannot acquire a lock that is already acquired" do
      acquired = recovery_lock.with_lock(light_name) do |data_store_1|
        expect do |block|
          acquired_nested = recovery_lock.with_lock(light_name, &block)
          expect(acquired_nested).to eq(false)
        end.not_to yield_control
      end

      expect(acquired).to eq(true)
    end

    it "can acquire after release" do
      acquired = recovery_lock.with_lock(light_name) { |data_store| }
      expect(acquired).to eq(true)

      acquired = recovery_lock.with_lock(light_name) { |data_store| }
      expect(acquired).to eq(true)
    end

    it "releases if block fails" do
      expect do
        recovery_lock.with_lock(light_name) { |data_store| raise "foo" }
      end.to raise_error("foo")

      acquired = recovery_lock.with_lock(light_name) { |data_store| }
      expect(acquired).to eq(true)
    end

    include ExceptionHelpers

    it "releases by timeout if redis fails" do
      expect(recovery_lock).to receive(:release_lock).and_raise(Redis::TimeoutError.new("foo")).once

      start = Process.clock_gettime(:CLOCK_MONOTONIC)
      suppress(Redis::TimeoutError) do
        recovery_lock.with_lock(light_name) { |data_store| }
      end
      remaining_ttl = lock_timeout - (Process.clock_gettime(:CLOCK_MONOTONIC) - start)
      sleep(remaining_ttl.fdiv(1000))

      recovery_lock2 = described_class.new(redis:, data_store:, lock_timeout:)
      acquired = recovery_lock2.with_lock(light_name) { |data_store| }
      expect(acquired).to eq(true)
    end
  end
end

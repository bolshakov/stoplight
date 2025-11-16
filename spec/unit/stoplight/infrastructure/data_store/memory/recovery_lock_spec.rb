# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::Memory::RecoveryLock do
  let(:recovery_lock) { described_class.new(data_store:) }

  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:light_name) { SecureRandom.uuid }

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
  end
end

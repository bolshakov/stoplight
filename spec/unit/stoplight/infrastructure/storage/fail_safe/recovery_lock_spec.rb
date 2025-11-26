# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::FailSafe::RecoveryLock do
  let(:fail_safe) do
    described_class.new(
      primary_store:, error_notifier:, failover_store:,
      circuit_breaker: test_circuit_breaker_class.new
    )
  end
  let(:failover_store) { Stoplight::Infrastructure::DataStore::Memory.new(recovery_lock_store:) }
  let(:recovery_lock_store) { Stoplight::Infrastructure::DataStore::Memory::RecoveryLockStore.new }
  let(:primary_store) { instance_double(Stoplight::Domain::Storage::RecoveryLock) }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size: 4, cool_off_time: 60, threshold: 3) }
  let(:error_notifier) { instance_double(Proc) }
  let(:name) { SecureRandom.uuid }
  let(:error) { StandardError.new("Test error") }

  let(:test_circuit_breaker_class) do
    Class.new(Stoplight::Domain::Light) do
      def initialize
      end

      def run(fallback)
        yield
      rescue => exception
        fallback.call(exception)
      end
    end
  end

  describe "#acquire_lock" do
    subject { fail_safe.acquire_lock }

    context "when primary store does not fail" do
      let(:recovery_token) { instance_double(Stoplight::Domain::RecoveryLockToken) }

      it "returns the token" do
        expect(error_notifier).not_to receive(:call)

        expect(primary_store).to receive(:acquire_lock).and_return(recovery_token)
        is_expected.to eq(recovery_token)
      end
    end

    context "when primary store fails" do
      let(:failover_recovery_token) { instance_double(Stoplight::Domain::RecoveryLockToken) }

      it "returns failover token" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:acquire_lock).and_raise(error)
        expect(failover_store).to receive(:acquire_lock).and_return(failover_recovery_token)

        is_expected.to eq(failover_recovery_token)
      end
    end
  end

  describe "#release_lock" do
    subject(:release_lock) { fail_safe.release_lock(recovery_lock_token) }

    context "with primary recovery lock token" do
      let(:recovery_lock_token) { Stoplight::Infrastructure::Storage::Redis::RecoveryLockToken.new }

      context "when store does not fail" do
        it "releases this token" do
          expect(error_notifier).not_to receive(:call)
          expect(primary_store).to receive(:release_lock).with(recovery_lock_token)

          release_lock
        end
      end

      context "when primary fails" do
        it "notifies but does not call to failover" do
          expect(error_notifier).to receive(:call).with(error)
          expect(primary_store).to receive(:release_lock).with(recovery_lock_token).and_raise(error)
          expect(failover_store).not_to receive(:release_lock)

          release_lock
        end
      end
    end

    context "with failover recovery lock token" do
      let(:recovery_lock_token) { Stoplight::Infrastructure::Storage::Memory::RecoveryLockToken.new }

      it "releases this token" do
        expect(error_notifier).not_to receive(:call)
        expect(failover_store).to receive(:release_lock).with(recovery_lock_token)

        release_lock
      end
    end
  end
end

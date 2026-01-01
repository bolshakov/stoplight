# frozen_string_literal: true

require "securerandom"

RSpec.describe Stoplight::Infrastructure::DataStore::FailSafe do
  let(:fail_safe) { described_class.new(data_store:, error_notifier:, failover_data_store:, circuit_breaker:) }
  let(:failover_data_store) { Stoplight::Infrastructure::Memory::DataStore.new(recovery_lock_store:, clock:) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:recovery_lock_store) { Stoplight::Infrastructure::Memory::DataStore::RecoveryLockStore.new }
  let(:config) { instance_double(Stoplight::Domain::Config, name:, window_size: 4, cool_off_time: 60, threshold: 3) }
  let(:name) { SecureRandom.uuid }
  let(:error_notifier) { instance_double(Proc) }
  let(:circuit_breaker) { Stoplight.system_light(SecureRandom.uuid) }

  describe "faulty data store" do
    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

    it "when primary store fails" do
      # Prepare: move internal circuit breaker into the red state
      allow(data_store).to receive(:names).and_raise(Redis::TimeoutError)
      config.threshold.times do
        expect { fail_safe.names }.not_to raise_error
      end

      # Verify: now the fallback data store is used
      RSpec::Mocks.space.proxy_for(data_store).reset
      allow(data_store).to receive(:names)
      allow(data_store).to receive(:record_success)

      fail_safe.record_success(config)
      expect(fail_safe.names).to include(config.name)

      expect(data_store).not_to have_received(:record_success), "expected to use fallback data store without trying primary"
      expect(data_store).not_to have_received(:names), "expected to use fallback data store without trying primary"

      # After cool_off_time, the primary data store is tried again
      Timecop.travel(Time.now + config.cool_off_time) do
        expect(data_store).to receive(:names).and_return(["recovered"])

        expect(fail_safe.names).to eq(["recovered"])
      end
    end
  end
end

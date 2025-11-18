# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::DataStoreFactory do
  subject { factory.create(data_store_config, container) }
  let(:factory) { described_class.new }

  let(:error_notifier) { Stoplight::Wiring::Default::ERROR_NOTIFIER }
  let(:failover_data_store) { Stoplight::Infrastructure::DataStore::Memory.new(recovery_lock_store:) }
  let(:recovery_lock_store) { nil }
  let(:container) do
    container = Stoplight::Infrastructure::DependencyInjection::Container.new
    container.register(:error_notifier, error_notifier)
    container.register(:failover_data_store, failover_data_store)
    container
  end

  context "with Stoplight::DataStore::Memory" do
    let(:data_store_config) { Stoplight::DataStore::Memory.new }

    before do
      container.register(:"data_store.memory.recovery_lock_store", recovery_lock_store)
    end

    it "returns data_store instance" do
      is_expected.to be_kind_of(Stoplight::Infrastructure::DataStore::Memory)
    end

    it "returns the same data store instance for the same config instance" do
      is_expected.to equal(factory.create(data_store_config, container))
    end
  end

  context "with Stoplight::DataStore::Redis", :redis do
    let(:data_store_config) { Stoplight::DataStore::Redis.new(redis, warn_on_clock_skew:) }
    let(:warn_on_clock_skew) { double("warn_on_clock_skew") }

    before do
      container.register(:"data_store.redis.recovery_lock_store", recovery_lock_store)
    end

    it "returns a new FailSafe instance wrapping the data_store" do
      is_expected.to be_a(Stoplight::Infrastructure::DataStore::FailSafe)
      is_expected.to have_attributes(
        data_store: be_kind_of(Stoplight::Infrastructure::DataStore::Redis),
        error_notifier:,
        failover_data_store:
      )
    end
  end
end

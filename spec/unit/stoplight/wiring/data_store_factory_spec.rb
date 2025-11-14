# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::DataStoreFactory do
  subject { described_class.create(data_store:, error_notifier:, failover_data_store:) }

  let(:error_notifier) { Stoplight::Wiring::Default::ERROR_NOTIFIER }
  let(:failover_data_store) { Stoplight::Infrastructure::DataStore::Memory.new }

  context "when data_store is a Memory instance" do
    let(:data_store) { Stoplight::Infrastructure::DataStore::Memory.new }

    it "returns the same data_store instance" do
      is_expected.to be(data_store)
    end
  end

  context "when data_store is a FailSafe instance with the same error_notifier" do
    let(:data_store) do
      Stoplight::Infrastructure::DataStore::FailSafe.new(
        data_store: Stoplight::Infrastructure::DataStore::Memory.new,
        error_notifier:,
        failover_data_store:,
        circuit_breaker: nil
      )
    end

    it "returns the same data_store instance" do
      is_expected.to be(data_store)
    end
  end

  context "when data_store is a FailSafe instance with a different error_notifier" do
    let(:underlying_data_store) { Stoplight::Infrastructure::DataStore::Memory.new }
    let(:underlying_error_notifier) { ->(error) { warn error } }

    let(:data_store) do
      Stoplight::Infrastructure::DataStore::FailSafe.new(
        data_store: underlying_data_store,
        error_notifier: underlying_error_notifier,
        failover_data_store:,
        circuit_breaker: nil
      )
    end

    it "returns a new FailSafe instance wrapping the data_store" do
      is_expected.to be_a(Stoplight::Infrastructure::DataStore::FailSafe)
      is_expected.to have_attributes(
        data_store: underlying_data_store,
        error_notifier: error_notifier
      )
    end
  end

  context "when data_store is another type" do
    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

    it "returns a new FailSafe instance wrapping the data_store" do
      is_expected.to be_a(Stoplight::Infrastructure::DataStore::FailSafe)
      is_expected.to have_attributes(data_store:, error_notifier:)
    end
  end
end

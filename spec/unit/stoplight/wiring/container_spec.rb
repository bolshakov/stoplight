# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::Container do
  let(:container) { described_class.with(**settings) }

  let(:settings) do
    {
      config:,
      data_store:,
      error_notifier:,
      notifiers:,
      traffic_control:,
      traffic_recovery:
    }
  end

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store) { Stoplight::Wiring::Default::DATA_STORE }
  let(:error_notifier) { Stoplight::Wiring::Default::ERROR_NOTIFIER }
  let(:notifiers) { Stoplight::Wiring::Default::NOTIFIERS }
  let(:traffic_control) { Stoplight::Wiring::Default::TRAFFIC_CONTROL }
  let(:traffic_recovery) { Stoplight::Wiring::Default::TRAFFIC_RECOVERY }

  describe "data_store" do
    subject { container.resolve(:data_store) }

    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

    it "wraps data store with fail safe" do
      is_expected.to be_a(Stoplight::Infrastructure::DataStore::FailSafe)
      is_expected.to have_attributes(
        data_store:,
        error_notifier:,
        failover_data_store: Stoplight::Wiring::Default::DATA_STORE
      )
    end
  end

  describe "notifiers" do
    subject { container.resolve(:notifiers) }

    let(:notifiers) { [notifier] }
    let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }

    it "wraps notifiers with fail safe" do
      is_expected.to contain_exactly(Stoplight::Wiring::FailSafeNotifier.new(notifier:, error_notifier:))
    end
  end
end

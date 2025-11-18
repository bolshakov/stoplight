# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::Container do
  let(:container) { described_class.with(**settings) }

  let(:settings) do
    {
      config:,
      data_store_config:,
      error_notifier:,
      notifiers:,
      traffic_control:,
      traffic_recovery:
    }
  end

  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:data_store_config) { Stoplight::Wiring::Default::DATA_STORE }
  let(:error_notifier) { Stoplight::Wiring::Default::ERROR_NOTIFIER }
  let(:notifiers) { Stoplight::Wiring::Default::NOTIFIERS }
  let(:traffic_control) { Stoplight::Wiring::Default::TRAFFIC_CONTROL }
  let(:traffic_recovery) { Stoplight::Wiring::Default::TRAFFIC_RECOVERY }

  describe "data_store" do
    subject { container.resolve(:data_store) }

    let(:data_store_config) { Stoplight::DataStore::Memory.new }

    it "wraps data store with fail safe" do
      is_expected.to be_kind_of(Stoplight::Infrastructure::DataStore::Memory)
    end
  end

  describe "notifiers" do
    subject { container.resolve(:notifiers) }

    let(:notifiers) { [notifier] }
    let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }

    it "wraps notifiers with fail safe" do
      is_expected.to contain_exactly(Stoplight::Infrastructure::Notifier::FailSafe.new(notifier:, error_notifier:))
    end
  end
end

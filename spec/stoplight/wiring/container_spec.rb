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
  let(:data_store) { Stoplight::Default::DATA_STORE }
  let(:error_notifier) { Stoplight::Default::ERROR_NOTIFIER }
  let(:notifiers) { Stoplight::Default::NOTIFIERS }
  let(:traffic_control) { Stoplight::Default::TRAFFIC_CONTROL }
  let(:traffic_recovery) { Stoplight::Default::TRAFFIC_RECOVERY }

  describe "data_store" do
    subject { container.resolve(:data_store) }

    let(:data_store) { instance_double(Stoplight::DataStore::Base) }

    it "wraps data store with fail safe" do
      is_expected.to eq(Stoplight::DataStore::FailSafe.new(data_store:, error_notifier:))
    end
  end

  describe "notifiers" do
    subject { container.resolve(:notifiers) }

    let(:notifiers) { [notifier] }
    let(:notifier) { instance_double(Stoplight::Notifier::Base) }

    it "wraps notifiers with fail safe" do
      is_expected.to contain_exactly(Stoplight::Notifier::FailSafe.new(notifier:, error_notifier:))
    end
  end
end

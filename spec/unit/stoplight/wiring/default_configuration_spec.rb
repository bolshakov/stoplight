# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::DefaultConfiguration do
  let(:default_config) { described_class.new }

  context "without any settings" do
    it "contains only default notifiers" do
      expect(default_config.notifiers).to eq(Stoplight::Wiring::Default::NOTIFIERS)
    end
  end

  describe "#to_config" do
    subject(:config) { configuration.to_config! }

    let(:configuration) { described_class.new }

    specify "#tracked_errors" do
      configuration.tracked_errors = KeyError

      expect(config.tracked_errors).to eq([KeyError])
    end

    specify "#skipped_errors" do
      configuration.skipped_errors = KeyError

      expect(config.skipped_errors).to eq([KeyError])
    end

    specify "#traffic_control" do
      configuration.traffic_control = :error_rate
      configuration.window_size = 60
      configuration.threshold = 0.3

      expect(config.traffic_control).to be_kind_of(Stoplight::Domain::TrafficControl::ErrorRate)
    end

    specify "#traffic_recovery" do
      configuration.traffic_recovery = :consecutive_successes

      expect(config.traffic_recovery).to be_kind_of(Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses)
    end
  end
end

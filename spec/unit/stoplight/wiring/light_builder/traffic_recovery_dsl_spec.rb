# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightBuilder::TrafficRecoveryDsl do
  subject(:traffic_recovery_out) { described_class.call(traffic_recovery) }

  context "when an instance of TrafficRecovery::Base" do
    let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }

    it "returns the same traffic recovery object" do
      is_expected.to eq(traffic_recovery)
    end
  end

  context "when :consecutive_successes" do
    let(:traffic_recovery) { :consecutive_successes }

    it "returns an instance of Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses" do
      is_expected.to eq(Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new)
    end
  end

  context "when unsupported option" do
    let(:traffic_recovery) { :latency }

    it "raises an error" do
      expect { traffic_recovery_out }.to raise_error(Stoplight::Error::ConfigurationError)
    end
  end
end

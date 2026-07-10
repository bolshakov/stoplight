# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightConfigurationDsl::TrafficControlDsl do
  subject(:traffic_control_out) { described_class.call(traffic_control) }

  context "when an instance of TrafficControl::Base" do
    let(:traffic_control) { Stoplight::Domain::TrafficControl::ConsecutiveErrors.new }

    it "returns the same traffic control object" do
      is_expected.to eq(traffic_control)
    end
  end

  context "when :consecutive_errors" do
    let(:traffic_control) { :consecutive_errors }

    it "returns an instance of Stoplight::Domain::TrafficControl::ConsecutiveErrors" do
      is_expected.to eq(Stoplight::Domain::TrafficControl::ConsecutiveErrors.new)
    end
  end

  context "when :error_rate" do
    let(:traffic_control) { :error_rate }

    it "returns an instance of Stoplight::Domain::TrafficControl::ErrorRate" do
      is_expected.to eq(Stoplight::Domain::TrafficControl::ErrorRate.new)
    end
  end

  context "when :error_rate with options" do
    let(:traffic_control) { {error_rate: {min_requests: 11}} }

    it "returns an instance of Stoplight::Domain::TrafficControl::ErrorRate with min_requests" do
      is_expected.to eq(Stoplight::Domain::TrafficControl::ErrorRate.new(min_requests: 11))
    end
  end

  context "when unsupported option" do
    let(:traffic_control) { :latency }

    it "raises an error" do
      expect { traffic_control_out }.to raise_error(Stoplight::Error::ConfigurationError)
    end
  end
end

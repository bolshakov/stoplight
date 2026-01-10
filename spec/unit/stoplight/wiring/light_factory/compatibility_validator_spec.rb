# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightFactory::CompatibilityValidator do
  subject(:validate) { described_class.call(config:) }

  let(:config) do
    instance_double(
      Stoplight::Domain::Config,
      threshold:,
      window_size:,
      recovery_threshold:,
      traffic_control:,
      traffic_recovery:
    )
  end
  let(:threshold) { 3 }
  let(:window_size) { nil }
  let(:recovery_threshold) { 1 }
  let(:traffic_control) { Stoplight::Domain::TrafficControl::ConsecutiveErrors.new }
  let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }

  context "when traffic control is not compatible with the config" do
    let(:traffic_control) { Stoplight::Domain::TrafficControl::ErrorRate.new }
    let(:threshold) { 5 } # must be 0..1
    let(:window_size) { 20 }

    it "raises a configuration errors" do
      expect { validate }.to raise_error(
        Stoplight::Error::ConfigurationError,
        include("incompatible with config: `threshold` should be between 0 and 1")
      )
    end
  end

  context "when traffic recovery is not compatible with the config" do
    let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }
    let(:recovery_threshold) { -4 }

    it "raises a configuration errors" do
      expect { validate }.to raise_error(
        Stoplight::Error::ConfigurationError,
        include("incompatible with config: `recovery_threshold` should be bigger than 0")
      )
    end
  end
end

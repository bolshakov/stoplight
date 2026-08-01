# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Memory::Storage::Registry do
  subject(:registry) { described_class.new }

  let(:config) do
    instance_double(
      Stoplight::Domain::Config,
      cool_off_time: 60.0,
      threshold: 5,
      recovery_threshold: 1,
      window_size: 300,
      tracked_errors: [StandardError],
      skipped_errors: [ArgumentError],
      traffic_control: Stoplight::Domain::TrafficControl::ConsecutiveErrors.new,
      traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new
    )
  end

  describe "#config_for" do
    subject { registry.config_for("stripe") }

    context "when the light was never registered" do
      it { is_expected.to be_nil }
    end

    context "when the light is registered" do
      before { registry.register(config) }

      it "is still nil, since the memory registry is a no-op" do
        is_expected.to be_nil
      end
    end
  end
end

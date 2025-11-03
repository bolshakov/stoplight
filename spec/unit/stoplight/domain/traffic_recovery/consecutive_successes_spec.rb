# frozen_string_literal: true

RSpec.describe Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses do
  describe "#check_compatibility" do
    subject(:strategy) { described_class.new.check_compatibility(config) }

    let(:config) { Stoplight::Domain::Config.empty.with(recovery_threshold:) }
    let(:recovery_threshold) { 42 }

    context "when recovery threshold is less then 1" do
      let(:recovery_threshold) { 0 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`recovery_threshold` should be bigger than 0")
      end
    end

    context "when recovery threshold is not an integer" do
      let(:recovery_threshold) { 14.87 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`recovery_threshold` should be an integer")
      end
    end
  end

  describe "#determine_color" do
    subject { described_class.new.determine_color(config, metrics, state_snapshot) }

    let(:config) { Stoplight::Domain::Config.empty.with(recovery_threshold:) }
    let(:recovery_threshold) { 2 }

    let(:metrics) { instance_double(Stoplight::Domain::Metrics, consecutive_successes:, last_error_at:) }
    let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_started_at:, recovery_scheduled_after:, color:) }
    let(:last_error_at) { recovery_started_at - 60 }
    let(:recovery_started_at) { Time.now }
    let(:recovery_scheduled_after) { nil }
    let(:color) { Stoplight::Domain::Color::YELLOW }

    context "when the last error happened after the recovery started" do
      let(:last_error_at) { recovery_started_at + 2 }
      let(:recovery_started_at) { Time.now }
      let(:consecutive_successes) { 0 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::RED) }
    end

    context "when the number of consecutive successes is greater than the threshold" do
      let(:consecutive_successes) { recovery_threshold + 1 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::GREEN) }
    end

    context "when the number of consecutive successes equals to the threshold" do
      let(:consecutive_successes) { recovery_threshold }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::GREEN) }
    end

    context "when the number of consecutive successes is less than the threshold" do
      let(:consecutive_successes) { recovery_threshold - 1 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::YELLOW) }
    end

    context "when already recovered on another Stoplight instance" do
      let(:color) { Stoplight::Domain::Color::GREEN }
      let(:consecutive_successes) { 0 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::PASS) }
    end
  end
end

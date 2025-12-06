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
    subject { described_class.new.determine_color(config, metrics) }

    let(:config) { Stoplight::Domain::Config.empty.with(recovery_threshold:) }
    let(:recovery_threshold) { 2 }

    let(:metrics) { instance_double(Stoplight::Domain::Metrics, consecutive_successes:, consecutive_errors:) }
    let(:color) { Stoplight::Domain::Color::YELLOW }

    context "when has errors" do
      let(:consecutive_errors) { 1 }
      let(:consecutive_successes) { 2 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::RED) }
    end

    context "when the number of consecutive successes is greater than the threshold" do
      let(:consecutive_errors) { 0 }
      let(:consecutive_successes) { recovery_threshold + 1 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::GREEN) }
    end

    context "when the number of consecutive successes equals to the threshold" do
      let(:consecutive_errors) { 0 }
      let(:consecutive_successes) { recovery_threshold }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::GREEN) }
    end

    context "when the number of consecutive successes is less than the threshold" do
      let(:consecutive_errors) { 0 }
      let(:consecutive_successes) { recovery_threshold - 1 }

      it { is_expected.to be(Stoplight::Domain::TrafficRecovery::YELLOW) }
    end
  end
end

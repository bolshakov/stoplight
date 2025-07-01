# frozen_string_literal: true

RSpec.describe Stoplight::TrafficRecovery::ConsecutiveSuccesses do
  describe "#check_compatibility" do
    subject(:strategy) { described_class.new.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Light::Config, recovery_threshold:) }
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
    subject { described_class.new.determine_color(config, metadata) }

    let(:config) { instance_double(Stoplight::Light::Config, recovery_threshold:) }
    let(:recovery_threshold) { 2 }

    let(:metadata) do
      instance_double(
        Stoplight::Metadata,
        consecutive_successes:,
        recovery_probe_successes:,
        last_error_at:,
        recovery_started_at:
      )
    end
    let(:last_error_at) { recovery_started_at - 60 }
    let(:recovery_started_at) { Time.now }

    context "when the last error happened after the recovery started" do
      let(:last_error_at) { recovery_started_at + 2 }
      let(:recovery_started_at) { Time.now }
      let(:consecutive_successes) { 0 }
      let(:recovery_probe_successes) { 1 }

      it { is_expected.to be(Stoplight::Color::RED) }
    end

    context "when the number of consecutive successes is greater than the threshold" do
      let(:consecutive_successes) { recovery_threshold + 1 }

      context "when the number of successes is less than the threshold" do
        let(:recovery_probe_successes) { recovery_threshold - 1 }

        it { is_expected.to be(Stoplight::Color::YELLOW) }
      end

      context "when the number of successes is equal to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold }

        it { is_expected.to be(Stoplight::Color::GREEN) }
      end

      context "when the number of successes is bigger to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold + 1 }

        it { is_expected.to be(Stoplight::Color::GREEN) }
      end
    end

    context "when the number of consecutive successes equals to the threshold" do
      let(:consecutive_successes) { recovery_threshold }

      context "when the number of successes is less than the threshold" do
        let(:recovery_probe_successes) { recovery_threshold - 1 }

        it { is_expected.to be(Stoplight::Color::YELLOW) }
      end

      context "when the number of successes is equal to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold }

        it { is_expected.to be(Stoplight::Color::GREEN) }
      end

      context "when the number of successes is bigger to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold + 1 }

        it { is_expected.to be(Stoplight::Color::GREEN) }
      end
    end

    context "when the number of consecutive successes is less than the threshold" do
      let(:consecutive_successes) { recovery_threshold - 1 }

      context "when the number of successes is less than the threshold" do
        let(:recovery_probe_successes) { recovery_threshold - 1 }

        it { is_expected.to be(Stoplight::Color::YELLOW) }
      end

      context "when the number of successes is equal to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold }

        it { is_expected.to be(Stoplight::Color::YELLOW) }
      end

      context "when the number of successes is bigger to the threshold" do
        let(:recovery_probe_successes) { recovery_threshold + 1 }

        it { is_expected.to be(Stoplight::Color::YELLOW) }
      end
    end
  end
end

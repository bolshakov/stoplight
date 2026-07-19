# frozen_string_literal: true

RSpec.describe Stoplight::Domain::TrafficControl::ConsecutiveErrors do
  describe "#check_compatibility" do
    subject(:strategy) { described_class.new.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Domain::Config, window_size:, threshold:) }
    let(:threshold) { 42 }
    let(:window_size) { nil }

    context "when stoplight tracks running window" do
      let(:window_size) { 600 }

      it { is_expected.to be_compatible }
    end

    context "when stoplight does not track running window" do
      let(:window_size) { nil }

      it { is_expected.to be_compatible }
    end

    context "when threshold is less then 1" do
      let(:threshold) { 0 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`threshold` should be bigger than 0")
      end
    end

    context "when threshold is not an integer" do
      let(:threshold) { 14.87 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`threshold` should be an integer")
      end
    end

    context "when threshold is nil" do
      let(:threshold) { nil }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`threshold` should be an integer")
      end
    end

    context "when threshold is a string" do
      let(:threshold) { "3" }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(strategy.error_messages).to eq("`threshold` should be an integer")
      end
    end
  end

  describe "#stop_traffic?" do
    subject { described_class.new.stop_traffic?(config, metadata) }

    let(:config) { instance_double(Stoplight::Domain::Config, threshold:, window_size:) }
    let(:metadata) { instance_double(Stoplight::Domain::MetricsSnapshot, consecutive_errors:) }

    context "when the window size is not sent" do
      let(:window_size) { nil }

      context "when the number of consecutive errors is greater than the threshold" do
        let(:consecutive_errors) { 3 }
        let(:threshold) { 2 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors is equal to the threshold" do
        let(:consecutive_errors) { 2 }
        let(:threshold) { 2 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors is less then the threshold" do
        let(:consecutive_errors) { 1 }
        let(:threshold) { 2 }

        it { is_expected.to be(false) }
      end
    end

    context "when the window size is set" do
      let(:window_size) { 600 }

      context "when the number of consecutive errors is greater than the threshold" do
        let(:consecutive_errors) { 2 }
        let(:threshold) { 1 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors equals to the threshold" do
        let(:consecutive_errors) { 1 }
        let(:threshold) { 1 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors is less than the threshold" do
        let(:consecutive_errors) { 1 }
        let(:threshold) { 2 }

        it { is_expected.to be(false) }
      end
    end
  end

  describe "#eql?" do
    it "returns true for equal instances" do
      strategy_a = described_class.new
      strategy_b = described_class.new

      expect(strategy_a.eql?(strategy_b)).to be(true)
    end

    it "returns false for different classes" do
      expect(described_class.new.eql?(Stoplight::Domain::TrafficControl::ErrorRate.new)).to be(false)
    end
  end
end

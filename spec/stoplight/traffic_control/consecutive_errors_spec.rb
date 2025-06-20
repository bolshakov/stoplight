# frozen_string_literal: true

RSpec.describe Stoplight::TrafficControl::ConsecutiveErrors do
  describe "#check_compatibility" do
    subject(:strategy) { described_class.new.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Light::Config, window_size:, threshold:) }
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
  end

  describe "#stop_traffic?" do
    subject { described_class.new.stop_traffic?(config, metadata) }

    let(:config) { instance_double(Stoplight::Light::Config, threshold:, window_size:) }
    let(:metadata) { instance_double(Stoplight::Metadata, consecutive_errors:, errors:) }

    context "when the window size is not sent" do
      let(:window_size) { nil }

      context "when the number of consecutive errors is greater than the threshold" do
        let(:consecutive_errors) { 3 }
        let(:errors) { 1 }
        let(:threshold) { 2 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors is equal to the threshold" do
        let(:consecutive_errors) { 2 }
        let(:errors) { 1 }
        let(:threshold) { 2 }

        it { is_expected.to be(true) }
      end

      context "when the number of consecutive errors is less then the threshold" do
        let(:consecutive_errors) { 1 }
        let(:errors) { 1 }
        let(:threshold) { 2 }

        it { is_expected.to be(false) }
      end
    end

    context "when the window size is set" do
      let(:window_size) { 600 }

      context "when the number of consecutive errors is greater than the threshold" do
        let(:consecutive_errors) { 2 }
        let(:threshold) { 1 }

        context "when the number of errors is less than the threshold" do
          let(:errors) { 0 }

          it { is_expected.to be(false) }
        end

        context "when the number of errors is equal to the threshold" do
          let(:errors) { 1 }

          it { is_expected.to be(true) }
        end

        context "when the number of errors is bigger to the threshold" do
          let(:errors) { 2 }

          it { is_expected.to be(true) }
        end
      end

      context "when the number of consecutive errors equals to the threshold" do
        let(:consecutive_errors) { 1 }
        let(:threshold) { 1 }

        context "when the number of errors is less than the threshold" do
          let(:errors) { 0 }

          it { is_expected.to be(false) }
        end

        context "when the number of errors is equal to the threshold" do
          let(:errors) { 1 }

          it { is_expected.to be(true) }
        end

        context "when the number of errors is bigger to the threshold" do
          let(:errors) { 2 }

          it { is_expected.to be(true) }
        end
      end

      context "when the number of consecutive errors is less than the threshold" do
        let(:consecutive_errors) { 1 }
        let(:threshold) { 2 }

        context "when the number of errors is less than the threshold" do
          let(:errors) { 0 }

          it { is_expected.to be(false) }
        end

        context "when the number of errors is equal to the threshold" do
          let(:errors) { 1 }

          it { is_expected.to be(false) }
        end

        context "when the number of errors is bigger to the threshold" do
          let(:errors) { 2 }

          it { is_expected.to be(false) }
        end
      end
    end
  end
end

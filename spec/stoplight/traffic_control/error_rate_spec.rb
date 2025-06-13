# frozen_string_literal: true

RSpec.describe Stoplight::TrafficControl::ErrorRate do
  subject(:traffic_control) { described_class.new }

  describe "#check_compatibility" do
    subject(:availability) { traffic_control.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Light::Config, window_size:, threshold:) }
    let(:threshold) { 0.1 }
    let(:window_size) { 600 }

    context "when stoplight tracks running window" do
      let(:window_size) { 600 }

      it { is_expected.to be_compatible }
    end

    context "when stoplight does not track running window" do
      let(:window_size) { nil }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(availability.error_messages).to eq("`window_size` should be set")
      end
    end

    context "when threshold is bigger then 1" do
      let(:threshold) { 1.1 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(availability.error_messages).to eq("`threshold` should be between 0 and 1")
      end
    end

    context "when threshold is less then 0" do
      let(:threshold) { -1 }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(availability.error_messages).to eq("`threshold` should be between 0 and 1")
      end
    end

    context "when threshold is slightly bigger then 0" do
      let(:threshold) { 0.01 }

      it { is_expected.to be_compatible }
    end

    context "when threshold is slightly less then 1" do
      let(:threshold) { 0.99 }

      it { is_expected.to be_compatible }
    end
  end

  describe "#stop_traffic?" do
    subject { traffic_control.stop_traffic?(config, metadata) }

    let(:config) { instance_double(Stoplight::Light::Config, window_size: 300, threshold: 0.6) }

    let(:metadata) do
      Stoplight::Metadata.new(successes:, failures:)
    end

    context "when there are no requests" do
      let(:successes) { 0 }
      let(:failures) { 0 }

      it "does not stop traffic" do
        is_expected.to be(false)
      end
    end

    context "when there is not enough requests" do
      let(:successes) { 0 }
      let(:failures) { 9 }

      it "does not stop traffic" do
        is_expected.to be(false)
      end
    end

    context "when there is enough requests" do
      context "when threshold is reached" do
        let(:successes) { 40 }
        let(:failures) { 60 }

        it "stops traffic" do
          is_expected.to be(true)
        end
      end

      context "when threshold is exceeded" do
        let(:successes) { 30 }
        let(:failures) { 70 }

        it "stops traffic" do
          is_expected.to be(true)
        end
      end

      context "when threshold is not reached" do
        let(:successes) { 41 }
        let(:failures) { 59 }

        it "does not stop traffic" do
          is_expected.to be(false)
        end
      end
    end
  end
end

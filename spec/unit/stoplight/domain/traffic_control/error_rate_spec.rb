# frozen_string_literal: true

RSpec.describe Stoplight::Domain::TrafficControl::ErrorRate do
  subject(:traffic_control) { described_class.new(min_requests:) }

  let(:min_requests) { 10 }

  describe "#check_compatibility" do
    subject(:availability) { traffic_control.check_compatibility(config) }

    let(:config) { Stoplight::Domain::Config.empty.with(window_size:, threshold:) }
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

    let(:config) { instance_double(Stoplight::Domain::Config, threshold:) }
    let(:metadata) { instance_double(Stoplight::Domain::Metrics, error_rate:, requests:) }

    let(:threshold) { 0.6 }

    context "when min requests satisfied" do
      let(:requests) { min_requests + 1 }

      context "when error rate reaches threshold" do
        let(:error_rate) { threshold }

        it "stops traffic" do
          is_expected.to be(true)
        end
      end

      context "when error rate exceeds threshold" do
        let(:error_rate) { threshold + 0.00001 }

        it "stops traffic" do
          is_expected.to be(true)
        end
      end

      context "when error rate below threshold" do
        let(:error_rate) { threshold - 0.00001 }

        it "does not stop traffic" do
          is_expected.to be(false)
        end
      end
    end

    context "when min requests not satisfied" do
      let(:requests) { min_requests - 1 }

      context "when error rate reaches threshold" do
        let(:error_rate) { threshold }

        it "does not stop traffic" do
          is_expected.to be(false)
        end
      end

      context "when error rate exceeds threshold" do
        let(:error_rate) { threshold + 0.00001 }

        it "does not stop traffic" do
          is_expected.to be(false)
        end
      end

      context "when error rate below threshold" do
        let(:error_rate) { threshold - 0.00001 }

        it "does not stop traffic" do
          is_expected.to be(false)
        end
      end
    end
  end
end

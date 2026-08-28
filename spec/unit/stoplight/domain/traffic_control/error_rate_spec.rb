# frozen_string_literal: true

RSpec.describe Stoplight::Domain::TrafficControl::ErrorRate do
  subject(:traffic_control) { described_class.new }

  describe "#check_compatibility" do
    subject(:availability) { traffic_control.check_compatibility(config) }

    let(:config) { instance_double(Stoplight::Domain::Config, window_size:, threshold:) }
    let(:threshold) { 0.1 }
    let(:window_size) { 600 }

    context "when stoplight tracks running window" do
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

    context "when threshold is nil" do
      let(:threshold) { nil }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(availability.error_messages).to eq("`threshold` should be a number")
      end
    end

    context "when threshold is not numeric" do
      let(:threshold) { "0.7" }

      it { is_expected.to be_incompatible }

      it "returns an error message" do
        expect(availability.error_messages).to eq("`threshold` should be a number")
      end
    end
  end

  describe "#stop_traffic?" do
    subject { traffic_control.stop_traffic?(config, metadata) }

    let(:config) { instance_double(Stoplight::Domain::Config, threshold:) }
    let(:metadata) { instance_double(Stoplight::Domain::MetricsSnapshot, error_rate:, requests:) }
    let(:threshold) { 0.6 }
    let(:min_requests) { 100 }

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

  describe "#name" do
    it "returns the policy name as a string" do
      expect(described_class.new.name).to eq("error_rate")
    end
  end

  describe "#eql?" do
    it "returns true for two instances" do
      expect(described_class.new.eql?(described_class.new)).to be(true)
    end

    it "returns false for a different class" do
      expect(described_class.new.eql?(Stoplight::Domain::TrafficControl::ConsecutiveErrors.new)).to be(false)
    end
  end
end

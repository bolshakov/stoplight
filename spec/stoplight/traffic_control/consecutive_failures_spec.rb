# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::TrafficControl::ConsecutiveFailures do
  subject { described_class.new.stop_traffic?(config, metadata) }

  let(:config) { instance_double(Stoplight::Light::Config, threshold:, window_size:) }
  let(:metadata) { instance_double(Stoplight::Metadata, consecutive_failures:, failures:) }

  context "when the window size is not sent" do
    let(:window_size) { nil }

    context "when the number of consecutive failures is greater than the threshold" do
      let(:consecutive_failures) { 3 }
      let(:failures) { 1 }
      let(:threshold) { 2 }

      it { is_expected.to be(true) }
    end

    context "when the number of consecutive failures is equal to the threshold" do
      let(:consecutive_failures) { 2 }
      let(:failures) { 1 }
      let(:threshold) { 2 }

      it { is_expected.to be(true) }
    end

    context "when the number of consecutive failures is less then the threshold" do
      let(:consecutive_failures) { 1 }
      let(:failures) { 1 }
      let(:threshold) { 2 }

      it { is_expected.to be(false) }
    end
  end

  context "when the window size is set" do
    let(:window_size) { 600 }

    context "when the number of consecutive failures is greater than the threshold" do
      let(:consecutive_failures) { 2 }
      let(:threshold) { 1 }

      context "when the number of failures is less than the threshold" do
        let(:failures) { 0 }

        it { is_expected.to be(false) }
      end

      context "when the number of failures is equal to the threshold" do
        let(:failures) { 1 }

        it { is_expected.to be(true) }
      end

      context "when the number of failures is bigger to the threshold" do
        let(:failures) { 2 }

        it { is_expected.to be(true) }
      end
    end

    context "when the number of consecutive failures equals to the threshold" do
      let(:consecutive_failures) { 1 }
      let(:threshold) { 1 }

      context "when the number of failures is less than the threshold" do
        let(:failures) { 0 }

        it { is_expected.to be(false) }
      end

      context "when the number of failures is equal to the threshold" do
        let(:failures) { 1 }

        it { is_expected.to be(true) }
      end

      context "when the number of failures is bigger to the threshold" do
        let(:failures) { 2 }

        it { is_expected.to be(true) }
      end
    end

    context "when the number of consecutive failures is less than the threshold" do
      let(:consecutive_failures) { 1 }
      let(:threshold) { 2 }

      context "when the number of failures is less than the threshold" do
        let(:failures) { 0 }

        it { is_expected.to be(false) }
      end

      context "when the number of failures is equal to the threshold" do
        let(:failures) { 1 }

        it { is_expected.to be(false) }
      end

      context "when the number of failures is bigger to the threshold" do
        let(:failures) { 2 }

        it { is_expected.to be(false) }
      end
    end
  end
end

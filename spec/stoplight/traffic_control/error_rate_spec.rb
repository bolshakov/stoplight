# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::TrafficControl::ErrorRate do
  let(:min_sample_size) { 5 }
  let(:strategy) { described_class.new(min_sample_size: min_sample_size) }

  let(:config) do
    instance_double("Stoplight::Light::Config", threshold: threshold)
  end

  let(:metadata) do
    instance_double("Stoplight::Metadata", successes: successes, failures: failures)
  end

  context "when error rate is below threshold" do
    let(:threshold) { 0.5 }
    let(:successes) { 8 }
    let(:failures) { 2 }

    it "does not stop traffic" do
      expect(strategy.stop_traffic?(config, metadata)).to eq(false)
    end
  end

  context "when error rate is above threshold" do
    let(:threshold) { 0.3 }
    let(:successes) { 2 }
    let(:failures) { 8 }

    it "stops traffic" do
      expect(strategy.stop_traffic?(config, metadata)).to eq(true)
    end
  end

  context "when sample size is too small" do
    let(:threshold) { 0.5 }
    let(:successes) { 2 }
    let(:failures) { 1 }

    it "does not stop traffic regardless of error rate" do
      expect(strategy.stop_traffic?(config, metadata)).to eq(false)
    end
  end

  context "when threshold is not a float between 0 and 1" do
    let(:threshold) { 2 }
    let(:successes) { 10 }
    let(:failures) { 10 }

    it "raises ArgumentError" do
      expect { strategy.stop_traffic?(config, metadata) }.to raise_error(ArgumentError)
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::EvaluationStrategy do
  subject { described_class.new.evaluate(config, metadata) }

  let(:config) { instance_double(Stoplight::Light::Config, threshold:) }
  let(:metadata) { instance_double(Stoplight::DataStore::Metadata, consecutive_failures:) }

  context "when the number of consecutive failures is greater than the threshold" do
    let(:consecutive_failures) { 2 }
    let(:threshold) { 1 }

    it { is_expected.to be(true) }
  end

  context "when the number of consecutive failures equals to the threshold" do
    let(:consecutive_failures) { 1 }
    let(:threshold) { 1 }

    it { is_expected.to be(true) }
  end

  context "when the number of consecutive failures is less than the threshold" do
    let(:consecutive_failures) { 1 }
    let(:threshold) { 2 }

    it { is_expected.to be(false) }
  end
end

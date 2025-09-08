# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Metadata do
  describe "#color" do
    subject(:color) { metadata.color(at: current_time) }

    let(:metadata) do
      Stoplight::Metadata.new(
        locked_state:,
        recovery_scheduled_after:,
        recovery_started_at:,
        breached_at:
      )
    end
    let(:current_time) { Time.now }
    let(:recovery_scheduled_after) { nil }
    let(:locked_state) { nil }
    let(:recovery_started_at) { nil }
    let(:breached_at) { nil }

    it { is_expected.to be(Stoplight::Color::GREEN) }

    context "when locked green" do
      let(:locked_state) { Stoplight::State::LOCKED_GREEN }

      it { is_expected.to be(Stoplight::Color::GREEN) }
    end

    context "when locked red" do
      let(:locked_state) { Stoplight::State::LOCKED_RED }

      it { is_expected.to be(Stoplight::Color::RED) }
    end

    context "when recovery scheduled before current time" do
      let(:recovery_scheduled_after) { current_time - 1 }

      it { is_expected.to be(Stoplight::Color::YELLOW) }
    end

    context "when recovery has started" do
      let(:recovery_started_at) { Time.now - 3 }

      it { is_expected.to be(Stoplight::Color::YELLOW) }
    end

    context "when threshold breached" do
      let(:breached_at) { Time.now - 3 }

      it { is_expected.to be(Stoplight::Color::RED) }
    end
  end

  describe "#error_rate" do
    context "when there successes or errors are nil" do
      let(:metadata) { Stoplight::Metadata.new(successes: nil, errors: nil) }

      it "returns 0" do
        expect(metadata.error_rate).to eq(0)
      end
    end

    context "when there are no successes or errors" do
      let(:metadata) { Stoplight::Metadata.new(successes: 0, errors: 0) }

      it "returns 0" do
        expect(metadata.error_rate).to eq(0)
      end
    end

    context "when there are successes and errors" do
      let(:metadata) { Stoplight::Metadata.new(successes: 10, errors: 5) }

      it "returns the error rate" do
        expect(metadata.error_rate).to eq(5.fdiv(15))
      end
    end
  end

  describe "#with" do
    subject { metadata.with(successes: "42") }

    let(:metadata) { Stoplight::Metadata.new }

    it "applies constructor logic" do
      is_expected.to have_attributes(successes: 42)
    end
  end
end

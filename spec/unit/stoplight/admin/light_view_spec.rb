# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightView do
  subject(:light) do
    described_class.new(
      id:,
      config:,
      color:,
      state:,
      failures:,
      state_snapshot:,
      recovery_metrics_snapshot:
    )
  end
  let(:id) { SecureRandom.uuid }
  let(:failures) { [latest_failure] }
  let(:latest_failure) { Stoplight::Domain::Failure.from_error(latest_exception, time: Time.now) }
  let(:latest_exception) { StandardError.new("bang!") }
  let(:color) { "green" }
  let(:name) { "light-specs" }
  let(:state) { Stoplight::State::UNLOCKED }
  let(:recovery_metrics_snapshot) { nil }
  let(:config) { instance_double(Stoplight::Domain::Config, name:, recovery_threshold: 13) }
  let(:state_snapshot) do
    instance_double(Stoplight::Domain::StateSnapshot, recovery_scheduled_after:)
  end
  let(:recovery_scheduled_after) { nil }

  describe "#description_title and #description_message" do
    subject(:description_title) { light.description_title }
    subject(:description_message) { light.description_message }
    subject(:description_comment) { light.description_comment }

    context "when the light is red" do
      let(:color) { Stoplight::Color::RED }
      let(:recovery_scheduled_after) { 3.minute.from_now }

      context "when locked red with an errors" do
        let(:state) { Stoplight::State::LOCKED_RED }
        let(:failures) { [latest_failure] }

        it { expect(description_title).to eq("Last Error") }
        it { expect(description_message).to eq("StandardError: bang!") }
        it { expect(description_comment).to eq("Override active - all requests blocked") }
      end

      context "when locked red without errors" do
        let(:state) { Stoplight::State::LOCKED_RED }
        let(:failures) { [] }

        it { expect(description_title).to eq("Locked Open") }
        it { expect(description_message).to eq("Circuit manually locked open") }
        it { expect(description_comment).to eq("Override active - all requests blocked") }
      end

      context "when unlocked" do
        let(:state) { Stoplight::State::UNLOCKED }
        let(:failures) { [latest_failure] }

        it { expect(description_title).to eq("Last Error") }
        it { expect(description_message).to eq("StandardError: bang!") }

        it { expect(description_comment).to match(/Will attempt recovery in 2 minutes, \d+ seconds/) }
      end

      context "when unlocked without an error" do
        let(:state) { Stoplight::State::UNLOCKED }
        let(:failures) { [] }

        it { expect(description_title).to eq("Last Error") }
        it { expect(description_message).to eq("Not available") }
        it { expect(description_comment).to match(/Will attempt recovery in 2 minutes, \d+ seconds/) }
      end

      context "when unlocked and recovery is overdue" do
        let(:state) { Stoplight::State::UNLOCKED }
        let(:recovery_scheduled_after) { 1.second.ago }

        it { expect(description_comment).to eq("Recovery started: awaiting test traffic") }
      end

      context "when unlocked and recovery_scheduled_after is nil" do
        let(:state) { Stoplight::State::UNLOCKED }
        let(:recovery_scheduled_after) { nil }

        it { expect(description_comment).to eq("Recovery started: awaiting test traffic") }
      end
    end

    context "when the light is yellow" do
      let(:color) { Stoplight::Color::YELLOW }
      let(:recovery_metrics_snapshot) { instance_double(Stoplight::Domain::MetricsSnapshot, consecutive_successes:) }
      let(:consecutive_successes) { 7 }

      it { expect(description_title).to eq("Testing Recovery") }
      it { expect(description_message).to eq("StandardError: bang!") }

      context "without probes" do
        let(:consecutive_successes) { 0 }

        it { expect(description_comment).to eq("Recovery started: awaiting test traffic") }
      end

      context "with probes" do
        let(:consecutive_successes) { 7 }

        it { expect(description_comment).to eq("Allowing limited test traffic (7 of 13 requests)") }
      end

      context "without an error" do
        let(:failures) { [] }

        it { expect(description_title).to eq("Testing Recovery") }
        it { expect(description_message).to eq("Not available") }
        it { expect(description_comment).to eq("Allowing limited test traffic (7 of 13 requests)") }
      end
    end

    context "when the light is green" do
      let(:color) { Stoplight::Color::GREEN }

      context "when locked green" do
        let(:state) { Stoplight::State::LOCKED_GREEN }

        it { expect(description_title).to eq("Forced Healthy") }
        it { expect(description_message).to eq("Circuit manually locked closed") }
        it { expect(description_comment).to eq("Override active - all requests processed") }
      end

      context "when unlocked" do
        let(:state) { Stoplight::State::UNLOCKED }

        it { expect(description_title).to eq("Healthy") }
        it { expect(description_message).to eq("No recent errors") }
        it { expect(description_comment).to eq("Operating normally") }
      end
    end
  end

  describe "#latest_failure" do
    subject { light.latest_failure }

    it { is_expected.to eq(latest_failure) }
  end

  describe "#as_json" do
    subject(:json) { light.as_json }

    it "returns a hash with the light's attributes" do
      is_expected.to eq({
        id:,
        name:,
        color:,
        locked: false,
        failures: failures
      })
    end
  end

  describe "#locked?" do
    context "when locked green" do
      let(:state) { "locked_green" }

      it { is_expected.to be_locked }
    end

    context "when locked red" do
      let(:state) { "locked_green" }

      it { is_expected.to be_locked }
    end

    context "when unlocked" do
      let(:state) { "unlocked" }

      it { is_expected.not_to be_locked }
    end
  end
end

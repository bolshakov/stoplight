# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightsRepository::Light do
  subject(:light) do
    described_class.new(
      name: name,
      color: color,
      state: state,
      failures: failures
    )
  end
  let(:failures) { [latest_failure] }
  let(:latest_failure) { Stoplight::Failure.from_error(latest_exception) }
  let(:latest_exception) { StandardError.new("bang!")}
  let(:color) { "green" }
  let(:name) { "light-specs" }
  let(:state) { Stoplight::State::UNLOCKED }

  describe "#description_title and #description_message" do
    subject(:description_title) { light.description_title }
    subject(:description_message) { light.description_message }
    subject(:description_comment) { light.description_comment }

    context "when the light is red" do
      let(:color) { Stoplight::Color::RED }

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
        it { expect(description_comment).to eq("Will attempt recovery after cooling period") }
      end
    end

    context "when the light is yellow" do
      let(:color) { Stoplight::Color::YELLOW }

      it { expect(description_title).to eq("Testing Recovery") }
      it { expect(description_message).to eq("StandardError: bang!") }
      it { expect(description_comment).to eq("Allowing limited test traffic (0 of 1 requests)") }
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

  describe "#last_check_in_words" do
    subject { light.last_check_in_words }

    context "when the last check was more than a second ago" do
      let(:latest_failure) { Stoplight::Failure.from_error(StandardError.new) }

      it { is_expected.to eq("just now") }
    end

    context "when the last check was less than a minute ago" do
      let(:latest_failure) { Stoplight::Failure.from_error(StandardError.new, time: Time.now - 10) }

      it { is_expected.to match(/\d+s ago/) }
    end

    context "when the last check was less than a hour ago" do
      let(:latest_failure) { Stoplight::Failure.from_error(StandardError.new, time: Time.now - 300) }

      it { is_expected.to match(/\d+m ago/) }
    end

    context "when the last check was less than a day ago" do
      let(:latest_failure) { Stoplight::Failure.from_error(StandardError.new, time: Time.now - 7200) }

      it { is_expected.to match(/\d+h ago/) }
    end
  end

  describe "#latest_failure" do
    subject{ light.latest_failure }

    it { is_expected.to eq(latest_failure) }
  end

  describe "#as_json" do
    subject(:json) { light.as_json }

    it "returns a hash with the light's attributes" do
      is_expected.to eq({
        name: name,
        color: color,
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

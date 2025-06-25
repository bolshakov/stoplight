# frozen_string_literal: true

RSpec.describe Stoplight::Metadata do
  describe "#color" do
    subject(:color) { metadata.color(at: current_time, jitter:) }

    let(:metadata) do
      Stoplight::Metadata.new(
        locked_state:,
        recovery_scheduled_after:,
        recovery_started_at:,
        breached_at:
      )
    end
    let(:jitter) { 10 }
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
      let(:recovery_scheduled_after) { current_time - jitter - 1 }

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
end

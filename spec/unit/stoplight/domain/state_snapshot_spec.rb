# frozen_string_literal: true

RSpec.describe Stoplight::Domain::StateSnapshot do
  let(:time) { Time.now }

  describe "#color" do
    subject(:color) { state_snapshot.color }

    let(:state_snapshot) do
      Stoplight::Domain::StateSnapshot.new(
        locked_state:,
        recovery_scheduled_after:,
        recovery_started_at:,
        breached_at:,
        time:
      )
    end
    let(:recovery_scheduled_after) { nil }
    let(:locked_state) { Stoplight::State::UNLOCKED }
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
      let(:recovery_scheduled_after) { time - 1 }

      it { is_expected.to be(Stoplight::Color::YELLOW) }
    end

    context "when recovery has started" do
      let(:recovery_started_at) { time - 3 }

      it { is_expected.to be(Stoplight::Color::YELLOW) }
    end

    context "when recovery is in the future due to clock skew" do
      let(:recovery_started_at) { time + 3 }

      it { is_expected.to be(Stoplight::Color::YELLOW) }
    end

    context "when threshold breached" do
      let(:breached_at) { time - 3 }

      it { is_expected.to be(Stoplight::Color::RED) }
    end
  end
end

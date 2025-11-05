# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Metadata do
  let(:current_time) { Time.now }

  def build_metadata(**attributes)
    Stoplight::Domain::Metadata.new(
      locked_state: nil,
      recovery_scheduled_after: nil,
      recovery_started_at: nil,
      breached_at: nil,
      current_time: nil,
      successes: nil,
      errors: nil,
      recovery_probe_successes: nil,
      recovery_probe_errors: nil,
      last_error_at: nil,
      last_success_at: nil,
      consecutive_errors: nil,
      consecutive_successes: nil,
      last_error: nil,
      recovered_at: nil,
      **attributes
    )
  end

  describe "#color" do
    subject(:color) { metadata.color }

    let(:metadata) do
      build_metadata(
        locked_state:,
        recovery_scheduled_after:,
        recovery_started_at:,
        breached_at:,
        current_time:
      )
    end
    let(:recovery_scheduled_after) { nil }
    let(:locked_state) { nil }
    let(:recovery_started_at) { nil }
    let(:breached_at) { nil }

    it { is_expected.to be(Stoplight::Domain::Color::GREEN) }

    context "when locked green" do
      let(:locked_state) { Stoplight::Domain::State::LOCKED_GREEN }

      it { is_expected.to be(Stoplight::Domain::Color::GREEN) }
    end

    context "when locked red" do
      let(:locked_state) { Stoplight::Domain::State::LOCKED_RED }

      it { is_expected.to be(Stoplight::Domain::Color::RED) }
    end

    context "when recovery scheduled before current time" do
      let(:recovery_scheduled_after) { current_time - 1 }

      it { is_expected.to be(Stoplight::Domain::Color::YELLOW) }
    end

    context "when recovery has started" do
      let(:recovery_started_at) { Time.now - 3 }

      it { is_expected.to be(Stoplight::Domain::Color::YELLOW) }
    end

    context "when threshold breached" do
      let(:breached_at) { Time.now - 3 }

      it { is_expected.to be(Stoplight::Domain::Color::RED) }
    end
  end

  describe "#error_rate" do
    context "when there are no successes or errors" do
      let(:metadata) { build_metadata(successes: 0, errors: 0, current_time:) }

      it "returns 0" do
        expect(metadata.error_rate).to eq(0)
      end
    end

    context "when there are successes and errors" do
      let(:metadata) { build_metadata(successes: 10, errors: 5, current_time:) }

      it "returns the error rate" do
        expect(metadata.error_rate).to eq(5.fdiv(15))
      end
    end
  end
end

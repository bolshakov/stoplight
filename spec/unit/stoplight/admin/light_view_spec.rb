# frozen_string_literal: true

RSpec.describe Stoplight::Admin::LightView do
  def build_metrics_snapshot(**attributes)
    Stoplight::Domain::MetricsSnapshot.new(
      successes: nil,
      errors: nil,
      consecutive_errors: 0,
      consecutive_successes: 0,
      last_error: nil,
      last_success_at: nil,
      **attributes
    )
  end

  subject(:light) do
    described_class.new(
      config:,
      state_snapshot:,
      metrics_snapshot:,
      recovery_metrics_snapshot:
    )
  end
  let(:id) { SecureRandom.uuid }
  let(:latest_failure) { Stoplight::Domain::Failure.from_error(latest_exception, time: Time.now) }
  let(:latest_exception) { StandardError.new("bang!") }
  let(:color) { "green" }
  let(:name) { "light-specs" }
  let(:state) { Stoplight::State::UNLOCKED }
  let(:metrics_snapshot) do
    instance_double(Stoplight::Domain::MetricsSnapshot,
      last_error: latest_failure)
  end
  let(:recovery_metrics_snapshot) { nil }
  let(:config) { instance_double(Stoplight::Domain::Config, id:, name:, recovery_threshold: 13) }
  let(:state_snapshot) do
    instance_double(Stoplight::Domain::StateSnapshot, recovery_scheduled_after:, color:, locked_state: state)
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

        it { expect(description_title).to eq("Last Error") }
        it { expect(description_message).to eq("StandardError: bang!") }
        it { expect(description_comment).to eq("Override active - all requests blocked") }
      end

      context "when locked red without errors" do
        let(:state) { Stoplight::State::LOCKED_RED }
        let(:latest_failure) { nil }

        it { expect(description_title).to eq("Locked Open") }
        it { expect(description_message).to eq("Circuit manually locked open") }
        it { expect(description_comment).to eq("Override active - all requests blocked") }
      end

      context "when unlocked" do
        let(:state) { Stoplight::State::UNLOCKED }

        it { expect(description_title).to eq("Last Error") }
        it { expect(description_message).to eq("StandardError: bang!") }

        it { expect(description_comment).to match(/Will attempt recovery in 2 minutes, \d+ seconds/) }
      end

      context "when unlocked without an error" do
        let(:state) { Stoplight::State::UNLOCKED }
        let(:latest_failure) { nil }

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
        let(:latest_failure) { nil }

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

  describe "#traffic_metric_label and #traffic_metric_value" do
    subject(:traffic_metric) { [light.traffic_metric_label, light.traffic_metric_value] }

    context "with unbounded metrics" do
      let(:metrics_snapshot) { build_metrics_snapshot(consecutive_errors: 3) }

      it "describes the consecutive failure streak" do
        expect(traffic_metric).to eq(["Consecutive failures", "3"])
      end
    end

    context "with windowed metrics" do
      let(:metrics_snapshot) { build_metrics_snapshot(successes: 3, errors: 2) }

      it "describes errors within the request window" do
        expect(traffic_metric).to eq(["Errors", "2 / 5 requests (40.0%)"])
      end
    end

    context "with an empty window" do
      let(:metrics_snapshot) { build_metrics_snapshot(successes: 0, errors: 0) }

      it "renders a zero error rate" do
        expect(traffic_metric).to eq(["Errors", "0 / 0 requests (0.0%)"])
      end
    end

    context "with a windowed snapshot missing its error rate" do
      let(:metrics_snapshot) do
        instance_double(
          Stoplight::Domain::MetricsSnapshot,
          last_error: nil,
          requests: 1,
          errors!: 0,
          error_rate: nil
        )
      end

      it "raises instead of rendering a misleading zero percent rate" do
        expect { light.traffic_metric_value }.to raise_error(TypeError, "error_rate must not be nil")
      end
    end
  end

  describe "#as_json" do
    subject(:json) { light.as_json }

    context "with unbounded metrics" do
      let(:metrics_snapshot) { build_metrics_snapshot(consecutive_errors: 3, last_error: latest_failure) }

      it "returns the existing JSON fields" do
        expect(json.keys).to eq([:id, :name, :color, :failures, :locked])
        expect(json).to eq({
          id:,
          name:,
          color:,
          failures: [latest_failure],
          locked: false
        })
      end
    end

    context "with windowed metrics" do
      let(:metrics_snapshot) do
        build_metrics_snapshot(successes: 3, errors: 2, consecutive_errors: 2, last_error: latest_failure)
      end

      it "returns the existing JSON shape without metric fields" do
        expect(json.keys).to eq([:id, :name, :color, :failures, :locked])
        expect(json).not_to include(:metrics, :failure_count, :errors, :requests, :error_rate)
        expect(json).to eq({
          id:,
          name:,
          color:,
          failures: [latest_failure],
          locked: false
        })
      end
    end

    it "does not expose the obsolete card metric reader" do
      expect(light).not_to respond_to(:failure_count)
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

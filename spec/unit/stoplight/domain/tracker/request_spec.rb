# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::Request do
  subject(:request_tracker) do
    described_class.new(state_store:, traffic_control:, notifiers:, config:, metrics_store:, emitter:)
  end

  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:traffic_control) { Stoplight::Domain::TrafficControl::ConsecutiveErrors.new }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config, name: name) }
  let(:name) { SecureRandom.uuid }

  specify "#record_success" do
    expect(metrics_store).to receive(:record_success)

    request_tracker.record_success
  end

  describe "#record_failure" do
    let(:exception) { KeyError.new("something went wrong") }
    let(:metrics) do
      Stoplight::Domain::MetricsSnapshot.new(
        successes: 2,
        errors: 3,
        consecutive_errors: 3,
        consecutive_successes: 0,
        last_error: nil,
        last_success_at: nil
      )
    end

    before do
      allow(metrics_store).to receive(:record_failure).with(exception)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics)
    end

    context "when traffic control decides to stop the traffic" do
      before do
        allow(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(true)
      end

      context "when successfully transitions to RED" do
        it "sends notifications about transition" do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
          expect(notifier).to receive(:notify).with(have_attributes(name:), Stoplight::Color::GREEN, Stoplight::Color::RED, exception)

          request_tracker.record_failure(exception)
        end

        it "emits a TrafficBreached event" do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
          allow(notifier).to receive(:notify)

          expect { request_tracker.record_failure(exception) }.to emit(Stoplight::Domain::Telemetry::TrafficBreached).with(
            from_color: Stoplight::Color::GREEN,
            to_color: Stoplight::Color::RED,
            policy: "consecutive_errors",
            failure: Stoplight::Domain::Telemetry::Failure.new(exception:, tracked: true),
            metrics: Stoplight::Domain::Telemetry::Metrics.new(
              successes: metrics.successes,
              errors: metrics.errors,
              consecutive_errors: metrics.consecutive_errors,
              consecutive_successes: metrics.consecutive_successes
            )
          )
        end
      end

      context "when failed to transition to RED" do
        it "does not send notification about transition" do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(false)
          expect(notifier).not_to receive(:notify)
          expect(emitter).not_to receive(:emit)

          request_tracker.record_failure(exception)
        end
      end
    end

    specify "when traffic control decides to continue the traffic flow" do
      expect(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(false)
      expect(emitter).not_to receive(:emit)

      request_tracker.record_failure(exception)
    end
  end
end

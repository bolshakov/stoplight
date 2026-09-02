# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::Request do
  subject(:request_tracker) { described_class.new(state_store:, traffic_control:, config:, metrics_store:, emitter:) }

  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:traffic_control) { instance_double(NullTrafficControl) }
  let(:config) { instance_double(Stoplight::Domain::Config, name: name) }
  let(:name) { SecureRandom.uuid }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:policy_name) { SecureRandom.uuid }

  specify "#record_success" do
    expect(metrics_store).to receive(:record_success)

    request_tracker.record_success
  end

  describe "#record_failure" do
    let(:exception) { KeyError.new("something went wrong") }
    let(:metrics) { instance_double(Stoplight::Domain::MetricsSnapshot) }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception).and_return(metrics)
    end

    specify "when traffic control decides to continue the traffic flow" do
      expect(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(false)

      request_tracker.record_failure(exception)
    end
  end

  describe "TrafficBreached telemetry" do
    let(:exception) { KeyError.new("something went wrong") }
    let(:metrics) do
      instance_double(Stoplight::Domain::MetricsSnapshot,
        successes: 10,
        errors: 3,
        consecutive_errors: 3,
        consecutive_successes: 0)
    end

    before do
      allow(metrics_store).to receive(:record_failure).with(exception).and_return(metrics)
      allow(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(true)
      allow(traffic_control).to receive(:name).and_return(policy_name)
    end

    context "when the transition to RED succeeds" do
      before do
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
      end

      it "emits a TrafficBreached event with the transition details" do
        expect { request_tracker.record_failure(exception) }.to emit(Stoplight::Domain::Telemetry::TrafficBreached).with(
          from_color: Stoplight::Color::GREEN,
          to_color: Stoplight::Color::RED,
          policy: policy_name,
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

    context "when the transition to RED fails (light already red)" do
      before do
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(false)
      end

      it "does not emit a TrafficBreached event" do
        expect { request_tracker.record_failure(exception) }.not_to emit(Stoplight::Domain::Telemetry::TrafficBreached)
      end
    end

    context "when traffic control does not stop the traffic" do
      before do
        allow(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(false)
      end

      it "does not emit a TrafficBreached event" do
        expect { request_tracker.record_failure(exception) }.not_to emit(Stoplight::Domain::Telemetry::TrafficBreached)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::RecoveryProbe do
  subject(:recorder) do
    described_class.new(state_store:, traffic_recovery:, notifiers:, config:, metrics_store:, emitter:)
  end

  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config, name: name) }
  let(:name) { SecureRandom.uuid }

  shared_examples "when recover to" do |recover_to:, transition_from:, transition_to:|
    context "when recover to #{recover_to}" do
      let(:metrics_after_probe) do
        Stoplight::Domain::MetricsSnapshot.new(
          successes: 0,
          errors: 1,
          consecutive_errors: 1,
          consecutive_successes: 0,
          last_error: nil,
          last_success_at: nil
        )
      end

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
        allow(state_store).to receive(:transition_to_color).with(transition_to).and_return(true)
      end

      it "sends notifications" do
        expect(metrics_store).to receive(:clear)
        expect(notifier).to receive(:notify).with(have_attributes(name:), transition_from, transition_to, nil)

        record_probe
      end

      if recover_to == Stoplight::Domain::TrafficRecovery::RED
        it "emits RecoveryFailed after transitioning to red" do
          allow(metrics_store).to receive(:clear)
          allow(notifier).to receive(:notify)

          expect { record_probe }.to emit(Stoplight::Domain::Telemetry::RecoveryFailed).with(
            from_color: Stoplight::Color::YELLOW,
            to_color: Stoplight::Color::RED,
            policy: "consecutive_successes",
            failure: expected_failure,
            metrics: Stoplight::Domain::Telemetry::Metrics.new(
              successes: metrics_after_probe.successes,
              errors: metrics_after_probe.errors,
              consecutive_errors: metrics_after_probe.consecutive_errors,
              consecutive_successes: metrics_after_probe.consecutive_successes
            )
          )
        end

        it "does not emit RecoveryFailed when another process already transitioned" do
          allow(state_store).to receive(:transition_to_color).with(transition_to).and_return(false)
          allow(metrics_store).to receive(:clear)
          allow(notifier).to receive(:notify)

          expect { record_probe }.not_to emit(Stoplight::Domain::Telemetry::RecoveryFailed)
        end
      end
    end
  end

  shared_examples "recovering after probe" do
    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::GREEN,
      transition_from: Stoplight::Color::YELLOW,
      transition_to: Stoplight::Color::GREEN

    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::RED,
      transition_from: Stoplight::Color::YELLOW,
      transition_to: Stoplight::Color::RED

    context "when recover to unexpected to outcome" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::MetricsSnapshot) }
      let(:recover_to) { "unexpected" }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "raises an error" do
        expect { record_probe }.to raise_error(/recovery strategy returned unexpected color/)
      end
    end

    context "when recover to YELLOW (needs more probes)" do
      let(:metrics_after_probe) do
        Stoplight::Domain::MetricsSnapshot.new(
          successes: 0,
          errors: 0,
          consecutive_errors: 0,
          consecutive_successes: 1,
          last_error: nil,
          last_success_at: nil
        )
      end
      let(:recover_to) { Stoplight::Domain::TrafficRecovery::YELLOW }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "don't transition" do
        expect(state_store).not_to receive(:transition_to_color)
        expect(metrics_store).not_to receive(:clear)
        expect(notifier).not_to receive(:notify)

        record_probe
      end

      it "does not emit RecoveryFailed" do
        expect { record_probe }.not_to emit(Stoplight::Domain::Telemetry::RecoveryFailed)
      end
    end
  end

  describe "#record_success" do
    subject(:record_probe) { recorder.record_success }

    let(:expected_failure) { nil }

    before do
      allow(metrics_store).to receive(:record_success)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "#record_failure" do
    subject(:record_probe) { recorder.record_failure(exception) }

    let(:exception) { KeyError.new("bang") }
    let(:expected_failure) { Stoplight::Domain::Telemetry::Failure.new(exception:, tracked: true) }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end
end

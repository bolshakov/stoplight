# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::RecoveryProbe do
  subject(:recorder) { described_class.new(state_store:, traffic_recovery:, config:, metrics_store:, emitter:) }

  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:traffic_recovery) { instance_double(NullTrafficRecovery) }
  let(:config) { instance_double(Stoplight::Domain::Config, name: name) }
  let(:name) { SecureRandom.uuid }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:policy_name) { SecureRandom.uuid }

  shared_examples "when recover to" do |recover_to:, transition_to:|
    context "when recover to #{recover_to}" do
      let(:metrics_after_probe) {
        instance_double(Stoplight::Domain::MetricsSnapshot,
          successes: 5,
          errors: 2,
          consecutive_errors: 0,
          consecutive_successes: 3,
          last_error: nil,
          last_success_at: nil)
      }
      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
        allow(state_store).to receive(:transition_to_color).with(transition_to).and_return(true)
        allow(traffic_recovery).to receive(:name).and_return(policy_name)
      end

      it "clears metrics" do
        expect(metrics_store).to receive(:clear)

        record_probe
      end

      context "when failed to transition to #{transition_to}" do
        before do
          allow(state_store).to receive(:transition_to_color).with(transition_to).and_return(false)
        end

        it "does not clear metrics" do
          expect(metrics_store).not_to receive(:clear)

          record_probe
        end
      end
    end
  end

  shared_examples "recovering after probe" do
    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::GREEN,
      transition_to: Stoplight::Color::GREEN

    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::RED,
      transition_to: Stoplight::Color::RED

    context "when recover to unexpected to outcome" do
      let(:metrics_after_probe) {
        instance_double(Stoplight::Domain::MetricsSnapshot,
          successes: 0, errors: 0, consecutive_errors: 0, consecutive_successes: 0)
      }
      let(:recover_to) { "unexpected" }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "raises an error" do
        expect { record_probe }.to raise_error(/recovery strategy returned unexpected color/)
      end
    end

    context "when recover to YELLOW (needs more probes)" do
      let(:metrics_after_probe) {
        instance_double(Stoplight::Domain::MetricsSnapshot,
          successes: 0, errors: 0, consecutive_errors: 0, consecutive_successes: 0)
      }
      let(:recover_to) { Stoplight::Domain::TrafficRecovery::YELLOW }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "don't transition" do
        expect(state_store).not_to receive(:transition_to_color)
        expect(metrics_store).not_to receive(:clear)

        record_probe
      end
    end
  end

  describe "#record_success" do
    subject(:record_probe) { recorder.record_success(duration_ms: 5.0) }

    before do
      allow(metrics_store).to receive(:record_success)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "#record_failure" do
    subject(:record_probe) { recorder.record_failure(exception, duration_ms: 3.0) }

    let(:exception) { KeyError.new("bang") }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "RecoverySucceeded telemetry" do
    let(:metrics_after_probe) {
      instance_double(Stoplight::Domain::MetricsSnapshot,
        successes: 5,
        errors: 2,
        consecutive_errors: 0,
        consecutive_successes: 3)
    }

    before do
      allow(metrics_store).to receive(:record_success)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
      allow(metrics_store).to receive(:clear)
    end

    context "when the probe changes from yellow to green" do
      before do
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::GREEN)
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::GREEN).and_return(true)
        allow(traffic_recovery).to receive(:name).and_return(policy_name)
      end

      it "emits a RecoverySucceeded event with the transition details" do
        expect { recorder.record_success(duration_ms: 5.0) }.to emit(Stoplight::Domain::Telemetry::RecoverySucceeded).with(
          from_color: Stoplight::Color::YELLOW,
          to_color: Stoplight::Color::GREEN,
          policy: policy_name,
          metrics: Stoplight::Domain::Telemetry::Metrics.new(
            successes: metrics_after_probe.successes,
            errors: metrics_after_probe.errors,
            consecutive_errors: metrics_after_probe.consecutive_errors,
            consecutive_successes: metrics_after_probe.consecutive_successes
          )
        )
      end

      it "emits exactly one RecoverySucceeded event" do
        recorder.record_success(duration_ms: 5.0)

        count = emitter.emitted.count { |event| event.instance_of?(Stoplight::Domain::Telemetry::RecoverySucceeded) }
        expect(count).to eq(1)
      end

      context "when state store fails to transition" do
        before do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::GREEN).and_return(false)
        end

        it "does not emit a RecoverySucceeded event" do
          expect { recorder.record_success(duration_ms: 5.0) }.not_to emit(Stoplight::Domain::Telemetry::RecoverySucceeded)
        end
      end
    end

    context "when the light stays yellow" do
      before do
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::YELLOW)
      end

      it "does not emit a RecoverySucceeded event" do
        expect { recorder.record_success(duration_ms: 5.0) }.not_to emit(Stoplight::Domain::Telemetry::RecoverySucceeded)
      end
    end

    context "when the probe changes from yellow to red" do
      before do
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::RED)
        allow(traffic_recovery).to receive(:name).and_return(policy_name)
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
      end

      it "does not emit a RecoverySucceeded event" do
        expect { recorder.record_success(duration_ms: 5.0) }.not_to emit(Stoplight::Domain::Telemetry::RecoverySucceeded)
      end
    end
  end

  describe "RecoveryProbeCompleted telemetry" do
    let(:metrics_after_probe) {
      instance_double(Stoplight::Domain::MetricsSnapshot,
        successes: 5,
        errors: 2,
        consecutive_errors: 0,
        consecutive_successes: 3)
    }
    let(:expected_progress) {
      Stoplight::Domain::Telemetry::Metrics.new(
        successes: metrics_after_probe.successes,
        errors: metrics_after_probe.errors,
        consecutive_errors: metrics_after_probe.consecutive_errors,
        consecutive_successes: metrics_after_probe.consecutive_successes
      )
    }

    before do
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
      allow(metrics_store).to receive(:clear)
      allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::YELLOW)
    end

    context "when a probe succeeds" do
      before { allow(metrics_store).to receive(:record_success) }

      it "emits RecoveryProbeCompleted with outcome :success" do
        expect { recorder.record_success(duration_ms: 5.0) }
          .to emit(Stoplight::Domain::Telemetry::RecoveryProbeCompleted).with(
            outcome: :success,
            duration_ms: 5.0,
            failure: nil,
            progress: expected_progress
          )
      end

      it "emits exactly one RecoveryProbeCompleted event per probe" do
        recorder.record_success(duration_ms: 5.0)

        count = emitter.emitted.count { |e| e.instance_of?(Stoplight::Domain::Telemetry::RecoveryProbeCompleted) }
        expect(count).to eq(1)
      end
    end

    context "when a probe fails" do
      let(:exception) { KeyError.new("bang") }

      before { allow(metrics_store).to receive(:record_failure).with(exception) }

      it "emits RecoveryProbeCompleted with outcome :failure" do
        expect { recorder.record_failure(exception, duration_ms: 3.0) }
          .to emit(Stoplight::Domain::Telemetry::RecoveryProbeCompleted).with(
            outcome: :failure,
            duration_ms: 3.0,
            failure: have_attributes(exception: exception, tracked: true),
            progress: expected_progress
          )
      end

      it "emits exactly one RecoveryProbeCompleted event per probe" do
        recorder.record_failure(exception, duration_ms: 3.0)

        count = emitter.emitted.count { |e| e.instance_of?(Stoplight::Domain::Telemetry::RecoveryProbeCompleted) }
        expect(count).to eq(1)
      end
    end

    context "when the probe transitions to green" do
      before do
        allow(metrics_store).to receive(:record_success)
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::GREEN)
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::GREEN).and_return(true)
        allow(traffic_recovery).to receive(:name).and_return(policy_name)
      end

      it "still emits RecoveryProbeCompleted" do
        expect { recorder.record_success(duration_ms: 5.0) }
          .to emit(Stoplight::Domain::Telemetry::RecoveryProbeCompleted)
      end
    end

    context "when the probe transitions to red" do
      let(:exception) { KeyError.new("bang") }

      before do
        allow(metrics_store).to receive(:record_failure).with(exception)
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::RED)
        allow(traffic_recovery).to receive(:name).and_return(policy_name)
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
      end

      it "still emits RecoveryProbeCompleted" do
        expect { recorder.record_failure(exception, duration_ms: 3.0) }
          .to emit(Stoplight::Domain::Telemetry::RecoveryProbeCompleted)
      end
    end
  end

  describe "RecoveryFailed telemetry" do
    let(:exception) { KeyError.new("bang") }
    let(:metrics_after_probe) {
      instance_double(Stoplight::Domain::MetricsSnapshot,
        successes: 0,
        errors: 1,
        consecutive_errors: 1,
        consecutive_successes: 0)
    }
    let(:expected_metrics) {
      Stoplight::Domain::Telemetry::Metrics.new(
        successes: metrics_after_probe.successes,
        errors: metrics_after_probe.errors,
        consecutive_errors: metrics_after_probe.consecutive_errors,
        consecutive_successes: metrics_after_probe.consecutive_successes
      )
    }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
      allow(metrics_store).to receive(:clear)
      allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::RED)
      allow(traffic_recovery).to receive(:name).and_return(policy_name)
      allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
    end

    it "emits RecoveryFailed with correct payload" do
      expect { recorder.record_failure(exception, duration_ms: 3.0) }
        .to emit(Stoplight::Domain::Telemetry::RecoveryFailed).with(
          from_color: Stoplight::Color::YELLOW,
          to_color: Stoplight::Color::RED,
          policy: policy_name,
          failure: have_attributes(exception: exception, tracked: true),
          metrics: expected_metrics
        )
    end

    it "emits exactly one RecoveryFailed event" do
      recorder.record_failure(exception, duration_ms: 3.0)

      count = emitter.emitted.count { |e| e.instance_of?(Stoplight::Domain::Telemetry::RecoveryFailed) }
      expect(count).to eq(1)
    end

    context "when state store fails to transition" do
      before do
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(false)
      end

      it "does not emit RecoveryFailed" do
        expect { recorder.record_failure(exception, duration_ms: 3.0) }
          .not_to emit(Stoplight::Domain::Telemetry::RecoveryFailed)
      end
    end

    context "when the light stays yellow" do
      before do
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::YELLOW)
      end

      it "does not emit RecoveryFailed" do
        expect { recorder.record_failure(exception, duration_ms: 3.0) }
          .not_to emit(Stoplight::Domain::Telemetry::RecoveryFailed)
      end
    end

    context "when the probe itself succeeds but recovery trips back to red" do
      before do
        allow(metrics_store).to receive(:record_success)
      end

      it "emits RecoveryFailed with failure: nil" do
        expect { recorder.record_success(duration_ms: 5.0) }
          .to emit(Stoplight::Domain::Telemetry::RecoveryFailed).with(
            from_color: Stoplight::Color::YELLOW,
            to_color: Stoplight::Color::RED,
            policy: policy_name,
            failure: nil,
            metrics: expected_metrics
          )
      end
    end

    context "when the light transitions to green" do
      before do
        allow(metrics_store).to receive(:record_success)
        allow(traffic_recovery).to receive(:determine_color).and_return(Stoplight::Domain::TrafficRecovery::GREEN)
        allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::GREEN).and_return(true)
      end

      it "does not emit RecoveryFailed" do
        expect { recorder.record_success(duration_ms: 5.0) }
          .not_to emit(Stoplight::Domain::Telemetry::RecoveryFailed)
      end
    end
  end
end

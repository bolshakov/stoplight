# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::YellowRunStrategy do
  subject(:strategy) do
    described_class.new(
      name:,
      notifiers: notifiers,
      request_tracker:,
      state_store:,
      metrics_store:,
      recovery_lock_store:,
      config:,
      run_recorder:,
      clock:,
      emitter:
    )
  end

  let(:name) { SecureRandom.uuid }
  let(:error_tracking_policy) { instance_double(Stoplight::Domain::ErrorTrackingPolicy) }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:recovery_lock_store) { instance_double(NullRecoveryLockStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:request_tracker) { instance_double(Stoplight::Domain::Tracker::RecoveryProbe) }
  let(:cool_off_time) { 60 }
  let(:config) { instance_double(Stoplight::Domain::Config, name:, cool_off_time:) }
  let(:emitter) { TestTelemetryEmitter.new }
  let(:run_recorder) { Stoplight::Domain::Telemetry::RunRecorder.new(emitter:, color: Stoplight::Color::YELLOW) }
  let(:clock) { instance_double(NullClock, monotonic_millis: 1.4) }

  describe "#exceute" do
    before do
      allow(strategy).to receive(:enter_recovery)
    end

    context "when recovery lock acquired" do
      let(:recovery_lock_token) { instance_double(NullRecoveryLockToken) }

      before do
        allow(recovery_lock_store).to receive(:acquire_lock).and_return(recovery_lock_token)
      end

      context "when code executes successfully" do
        subject(:result) { strategy.execute(nil, state_snapshot: nil, error_tracking_policy:, &code) }

        let(:code) { -> { "Success" } }

        it "returns result" do
          expect(request_tracker).to receive(:record_success).with(duration_ms: anything)
          expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

          expect(result).to eq("Success")
        end

        it "produces RunCompleted event" do
          allow(request_tracker).to receive(:record_success)
          allow(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)
          expect(clock).to receive(:monotonic_millis).and_return(1.4, 2.2)

          expect { result }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
            outcome: :success,
            color: "yellow",
            duration_ms: be_within(0.00001).of(0.8),
            failure: nil,
            fallback_used: false,
            retry_after: nil
          )
        end
      end

      context "when nobody is subscribed to RunCompleted" do
        subject(:result) { strategy.execute(nil, state_snapshot: nil, error_tracking_policy:, &code) }

        let(:code) { -> { "Success" } }
        let(:run_recorder) { instance_double(Stoplight::Domain::Telemetry::RunRecorder, subscribed?: false, record_success: nil) }

        it "still captures duration for probe telemetry" do
          expect(request_tracker).to receive(:record_success).with(duration_ms: be_a(Float))
          expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

          expect(result).to eq("Success")
        end
      end

      context "when code fails" do
        subject(:result) { strategy.execute(fallback, state_snapshot: nil, error_tracking_policy:, &code) }

        let(:error) { StandardError.new("Test error") }
        let(:code) { -> { raise error } }

        before do
          allow(error_tracking_policy).to receive(:track?).with(error).and_return(track_error)
        end

        context "when error is tracked" do
          let(:track_error) { true }

          context "when fallback is not provided" do
            let(:fallback) { nil }

            it "records failure, notify and raises the error" do
              expect(request_tracker).to receive(:record_failure).with(error, duration_ms: anything)
              expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

              expect { result }.to raise_error(error)
            end

            it "produces RunCompleted event" do
              expect(request_tracker).to receive(:record_failure).with(error, duration_ms: anything)
              allow(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)
              expect(clock).to receive(:monotonic_millis).and_return(1.4, 2.2)

              expect do
                expect { result }.to raise_error(error)
              end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
                outcome: :failure,
                color: "yellow",
                duration_ms: be_within(0.00001).of(0.8),
                failure: have_attributes(exception: error, tracked: true),
                fallback_used: false,
                retry_after: nil
              )
            end
          end

          context "when fallback is provided" do
            let(:fallback) do
              ->(error) {
                @error = error
                "Fallback"
              }
            end

            it "records failure, notify and returns the fallback" do
              expect(request_tracker).to receive(:record_failure).with(error, duration_ms: anything)
              expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

              expect(result).to eq("Fallback")
              expect(@error).to eq(error)
            end

            it "produces RunCompleted event" do
              expect(request_tracker).to receive(:record_failure).with(error, duration_ms: anything)
              allow(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)
              expect(clock).to receive(:monotonic_millis).and_return(1.4, 2.2)

              expect { result }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
                outcome: :failure,
                color: "yellow",
                duration_ms: be_within(0.00001).of(0.8),
                failure: have_attributes(exception: error, tracked: true),
                fallback_used: true,
                retry_after: nil
              )
            end
          end
        end

        context "when error is not tracked" do
          let(:fallback) { nil }
          let(:track_error) { false }

          it "records success and raises the error" do
            expect(request_tracker).to receive(:record_success).with(duration_ms: anything)
            expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)
            expect(clock).to receive(:monotonic_millis).and_return(1.4, 2.2)

            expect do
              expect { result }.to raise_error(StandardError, "Test error")
            end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
              outcome: :success,
              color: "yellow",
              duration_ms: be_within(0.00001).of(0.8),
              failure: have_attributes(exception: error, tracked: false),
              fallback_used: false,
              retry_after: nil
            )
          end
        end
      end

      context "when success bookkeeping raises" do
        subject(:result) { strategy.execute(fallback, state_snapshot: nil, error_tracking_policy:, &code) }

        let(:code) { -> { "Success" } }
        let(:bookkeeping_error) { StandardError.new("metrics store unavailable") }
        let(:fallback_calls) { [] }
        let(:fallback) { ->(error) { fallback_calls << error } }

        before do
          allow(request_tracker).to receive(:record_success).and_raise(bookkeeping_error)
          allow(request_tracker).to receive(:record_failure)
          allow(error_tracking_policy).to receive(:track?).and_return(true)
        end

        it "surfaces the bookkeeping error without misreporting it as a probe failure" do
          expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

          expect { result }.to raise_error(bookkeeping_error)

          expect(error_tracking_policy).not_to have_received(:track?)
          expect(request_tracker).not_to have_received(:record_failure)
          expect(fallback_calls).to be_empty
        end
      end

      context "when entering recovery raises" do
        subject(:result) { strategy.execute(fallback, state_snapshot: nil, error_tracking_policy:, &code) }

        let(:code) { -> { "Success" } }
        let(:recovery_error) { StandardError.new("state store unavailable") }
        let(:fallback_calls) { [] }
        let(:fallback) { ->(error) { fallback_calls << error } }

        before do
          allow(strategy).to receive(:enter_recovery).and_raise(recovery_error)
          allow(request_tracker).to receive(:record_failure)
          allow(error_tracking_policy).to receive(:track?).and_return(true)
        end

        it "surfaces the recovery error without misreporting it as a probe failure" do
          expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

          expect { result }.to raise_error(recovery_error)

          expect(error_tracking_policy).not_to have_received(:track?)
          expect(request_tracker).not_to have_received(:record_failure)
          expect(fallback_calls).to be_empty
        end
      end
    end

    context "when recovery lock is not acquired" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_scheduled_after: Time.now) }

      before do
        allow(recovery_lock_store).to receive(:acquire_lock).and_return(nil)
      end

      context "when fallback is provided" do
        let(:fallback) do
          ->(error) {
            @error = error
            "Fallback"
          }
        end

        it "returns the fallback result without yielding" do
          expect do |code|
            result = strategy.execute(fallback, state_snapshot:, error_tracking_policy:, &code)
            expect(result).to eq("Fallback")
          end.not_to yield_control

          expect(@error).to eq(nil)
        end

        it "does not measure duration for a blocked run" do
          expect(clock).not_to receive(:monotonic_millis)

          strategy.execute(fallback, state_snapshot:, error_tracking_policy:) {}
        end

        it "produces RunCompleted event" do
          expect {
            strategy.execute(fallback, state_snapshot:, error_tracking_policy:) {}
          }.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
            outcome: :blocked,
            color: "yellow",
            duration_ms: nil,
            failure: nil,
            fallback_used: true,
            retry_after: state_snapshot.recovery_scheduled_after
          )
        end
      end

      context "when fallback is not provided" do
        let(:fallback) { nil }

        it "raises RedLight without yielding" do
          expect do |code|
            expect { strategy.execute(fallback, state_snapshot:, error_tracking_policy:, &code) }.to raise_error(Stoplight::Error::RedLight) { |error|
              expect(error.light_name).to eq(name)
              expect(error.cool_off_time).to eq(cool_off_time)
              expect(error.retry_after).to eq(state_snapshot.recovery_scheduled_after)
            }
          end.not_to yield_control
        end

        it "does not measure duration for a blocked run" do
          expect(clock).not_to receive(:monotonic_millis)

          begin
            strategy.execute(fallback, state_snapshot:, error_tracking_policy:) {}
          rescue Stoplight::Error::RedLight
            nil
          end
        end

        it "produces RunCompleted event" do
          expect do
            expect do
              strategy.execute(fallback, state_snapshot:, error_tracking_policy:) {}
            end.to raise_error(Stoplight::Error::RedLight) { |error|
              expect(error.light_name).to eq(name)
            }
          end.to emit(Stoplight::Domain::Telemetry::RunCompleted).with(
            outcome: :blocked,
            color: "yellow",
            duration_ms: nil,
            failure: nil,
            fallback_used: false,
            retry_after: state_snapshot.recovery_scheduled_after
          )
        end
      end
    end
  end

  describe "#enter_recovery" do
    subject(:enter_recovery) { strategy.__send__(:enter_recovery, state_snapshot) }

    context "when recovery has already started" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_started?: true) }

      it "does not send notifications or emit events" do
        expect(notifier).not_to receive(:notify)

        expect {
          enter_recovery
        }.not_to emit(Stoplight::Domain::Telemetry::RecoveryStarted)
      end
    end

    context "when recovery has not yet started" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_started?: false, breached_at:) }
      let(:breached_at) { instance_double(Time) }

      it "notifies if able to transition to YELLOW" do
        expect(metrics_store).to receive(:clear)
        expect(state_store).to receive(:transition_to_color).with(Stoplight::Color::YELLOW)
        expect(notifier).to receive(:notify).with(have_attributes(name:), Stoplight::Color::RED, Stoplight::Color::YELLOW, nil)

        enter_recovery
      end

      it "emits RecoveryStarted" do
        allow(metrics_store).to receive(:clear)
        allow(state_store).to receive(:transition_to_color)
        allow(notifier).to receive(:notify)

        expect {
          enter_recovery
        }.to emit(Stoplight::Domain::Telemetry::RecoveryStarted).with(
          from_color: Stoplight::Color::RED,
          to_color: Stoplight::Color::YELLOW,
          breached_at:
        )
      end
    end
  end
end

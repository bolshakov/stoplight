# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::YellowRunStrategy do
  subject(:strategy) do
    described_class.new(
      name:,
      error_tracking_policy:,
      notifiers: notifiers,
      request_tracker:,
      red_run_strategy:,
      state_store:,
      metrics_store:,
      recovery_lock_store:,
      config:
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
  let(:red_run_strategy) { Stoplight::Domain::Strategies::RedRunStrategy.new(name:, cool_off_time:) }
  let(:cool_off_time) { 60 }
  let(:config) { instance_double(Stoplight::Domain::Config, name:) }

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
        subject(:result) { strategy.execute(nil, state_snapshot: nil, &code) }

        let(:code) { -> { "Success" } }

        it "returns result" do
          expect(request_tracker).to receive(:record_success)
          expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

          expect(result).to eq("Success")
        end
      end

      context "when code fails" do
        subject(:result) { strategy.execute(fallback, state_snapshot: nil, &code) }

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
              expect(request_tracker).to receive(:record_failure).with(error)
              expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

              expect { result }.to raise_error(error)
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
              expect(request_tracker).to receive(:record_failure).with(error)
              expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

              expect(result).to eq("Fallback")
              expect(@error).to eq(error)
            end
          end
        end

        context "when error is not tracked" do
          let(:fallback) { nil }
          let(:track_error) { false }

          it "records success and raises the error" do
            expect(request_tracker).to receive(:record_success)
            expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock_token)

            expect { result }.to raise_error(StandardError, "Test error")
          end
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
            result = strategy.execute(fallback, state_snapshot:, &code)
            expect(result).to eq("Fallback")
          end.not_to yield_control

          expect(@error).to eq(nil)
        end
      end

      context "when fallback is not provided" do
        let(:fallback) { nil }

        it "raises RedLight without yielding" do
          expect do |code|
            expect { strategy.execute(fallback, state_snapshot:, &code) }.to raise_error(Stoplight::Error::RedLight, name) { |error|
              expect(error.cool_off_time).to eq(cool_off_time)
              expect(error.retry_after).to eq(state_snapshot.recovery_scheduled_after)
            }
          end.not_to yield_control
        end
      end
    end
  end

  describe "#enter_recovery" do
    subject(:enter_recovery) { strategy.__send__(:enter_recovery, state_snapshot) }

    context "when recovery has already started" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_started?: true) }

      it "does not send notifications" do
        expect(notifier).not_to receive(:notify)

        enter_recovery
      end
    end

    context "when recovery has not yet started" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, recovery_started?: false) }

      it "notifies if able to transition to YELLO" do
        expect(metrics_store).to receive(:clear)
        expect(state_store).to receive(:transition_to_color).with(Stoplight::Color::YELLOW)
        expect(notifier).to receive(:notify).with(have_attributes(name:), Stoplight::Color::RED, Stoplight::Color::YELLOW, nil)

        enter_recovery
      end
    end
  end
end

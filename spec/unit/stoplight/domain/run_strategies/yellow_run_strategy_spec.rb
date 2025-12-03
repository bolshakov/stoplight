# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::YellowRunStrategy do
  subject(:strategy) do
    described_class.new(
      config:,
      notifiers: notifiers,
      request_tracker:,
      red_run_strategy:,
      state_store:,
      metrics_store:,
      recovery_lock_store:
    )
  end

  let(:notifiers) { [notifier] }
  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:recovery_lock_store) { instance_double(Stoplight::Domain::Storage::RecoveryLock) }
  let(:state_store) { instance_double(Stoplight::Domain::Storage::State) }
  let(:metrics_store) { instance_double(Stoplight::Domain::Storage::Metrics) }
  let(:request_tracker) { instance_double(Stoplight::Domain::Tracker::RecoveryProbe) }
  let(:red_run_strategy) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }

  describe "#exceute" do
    before do
      allow(strategy).to receive(:enter_recovery)
    end

    context "when recovery lock acquired" do
      let(:recovery_lock_token) { instance_double(Stoplight::Domain::RecoveryLockToken) }

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
          allow(config).to receive(:track_error?).and_return(track_error)
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
      let(:value) { instance_double(Object) }
      let(:fallback) { instance_double(Proc) }
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot) }

      it "delegates to red_run_strategy" do
        expect(recovery_lock_store).to receive(:acquire_lock).and_return(nil)
        expect(red_run_strategy).to receive(:execute).with(fallback, state_snapshot:).and_return(value)

        expect do |code|
          result = strategy.execute(fallback, state_snapshot:, &code)
          expect(result).to eq(value)
        end.not_to yield_control
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
        expect(state_store).to receive(:transition_to_color).with(Stoplight::Domain::Color::YELLOW)
        expect(notifier).to receive(:notify).with(config, Stoplight::Domain::Color::RED, Stoplight::Domain::Color::YELLOW, nil)

        enter_recovery
      end
    end
  end
end

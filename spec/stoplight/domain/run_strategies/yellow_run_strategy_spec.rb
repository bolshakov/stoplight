# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::YellowRunStrategy do
  subject(:strategy) do
    described_class.new(
      config:,
      data_store:,
      notifiers: [notifier],
      traffic_recovery:
    )
  end

  let(:config) do
    Stoplight::Domain::Config.empty.with(
      name: "foo",
      tracked_errors: [StandardError],
      skipped_errors: [],
      cool_off_time: 60
    )
  end
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }
  let(:in_metadata) { instance_double(Stoplight::Domain::Metadata, color: Stoplight::Color::YELLOW, recovery_scheduled_after:) }
  let(:out_metadata) { instance_double(Stoplight::Domain::Metadata) }
  let(:recovery_scheduled_after) { nil }

  shared_examples Stoplight::Domain::Strategies::YellowRunStrategy do
    shared_examples "recovery success" do
      before do
        expect(traffic_recovery).to receive(:determine_color).with(config, out_metadata).and_return(recovery_result)
      end

      context "when it enters yellow state after cool off time expiring" do
        let(:recovery_result) { Stoplight::Domain::TrafficRecovery::GREEN }
        let(:recovery_scheduled_after) { Time.now - 10 }

        let(:code) { -> { "Success" } }

        it "transitions to yellow before the probe" do
          expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::YELLOW, nil)
          expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::GREEN, nil)
          expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

          expect(result).to eq("Success")
        end
      end

      context "when recovery strategy returns PASS" do
        let(:recovery_result) { Stoplight::Domain::TrafficRecovery::PASS }

        it "does not make any recovery decisions" do
          expect(data_store).not_to receive(:transition_to_color)
          expect(notifier).not_to receive(:notify)
          allow(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

          suppress(StandardError) { result }
        end
      end

      context "when recovery strategy returns GREEN" do
        let(:recovery_result) { Stoplight::Domain::TrafficRecovery::GREEN }

        context "when switched to GREEN" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(true)
          end

          it "records success, notify and returns result" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::GREEN, nil)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end

        context "when not switched to GREEN" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(false)
          end

          it "records success and returns result without a notification" do
            expect(notifier).not_to receive(:notify)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end
      end

      context "when recovery strategy returns RED" do
        let(:recovery_result) { Stoplight::Domain::TrafficRecovery::RED }

        context "when switched to RED" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
          end

          it "records success, notify and returns result" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::RED, nil)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end

        context "when not switched to RED" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(false)
          end

          it "records success and returns result without a notification" do
            expect(notifier).not_to receive(:notify)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end
      end

      context "when recovery strategy returns YELLOW" do
        let(:recovery_result) { Stoplight::Domain::TrafficRecovery::YELLOW }

        context "when switched to YELLOW" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::YELLOW).and_return(true)
          end

          it "records failure, notify and raises an exception" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::YELLOW, nil)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end

        context "when not switched to YELLOW" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::YELLOW).and_return(false)
          end

          it "records failure, raises an exception without a notification" do
            expect(notifier).not_to receive(:notify)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

            suppress(StandardError) { result }
          end
        end
      end

      context "when recovery strategy returns unexpected color" do
        let(:recovery_result) { :unexpected_color }

        it "raises an error" do
          expect(notifier).not_to receive(:notify)
          expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(out_metadata)

          expect { result }.to raise_error(/recovery strategy returned an expected color/)
        end
      end
    end

    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, metadata: in_metadata, &code) }

      let(:code) { -> { "Success" } }
      let(:failures) { [Stoplight::Failure.from_error(StandardError.new)] }

      it_behaves_like "recovery success"
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, metadata: in_metadata, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }

      context "when error is tracked" do
        let(:config) { super().with(tracked_errors: [error]) }

        context "when fallback is not provided" do
          let(:fallback) { nil }

          before do
            expect(traffic_recovery).to receive(:determine_color).with(config, out_metadata).and_return(recovery_result)
          end

          context "when recovery strategy returns GREEN" do
            let(:recovery_result) { Stoplight::Domain::TrafficRecovery::GREEN }

            context "when switched to GREEN" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(true)
              end

              it "records failure, notify and raises an exception" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::GREEN, nil)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end

            context "when not switched to GREEN" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(false)
              end

              it "records success and raises an exception without a notification" do
                expect(notifier).not_to receive(:notify)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end

          context "when recovery strategy returns RED" do
            let(:recovery_result) { Stoplight::Domain::TrafficRecovery::RED }

            context "when switched to RED" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
              end

              it "records failure, notify and raises an exception" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::RED, nil)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end

            context "when not switched to RED" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(false)
              end

              it "records failure and raises an exception without a notification" do
                expect(notifier).not_to receive(:notify)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end

          context "when recovery strategy returns YELLOW" do
            let(:recovery_result) { Stoplight::Domain::TrafficRecovery::YELLOW }

            context "when switched to YELLOW" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::YELLOW).and_return(true)
              end

              it "records failure, notify and raises an exception" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::YELLOW, nil)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end

            context "when not switched to YELLOW" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::YELLOW).and_return(false)
              end

              it "records failure, and raises an exception without a notification" do
                expect(notifier).not_to receive(:notify)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end
        end

        context "when fallback is provided" do
          let(:fallback) {
            ->(error) {
              @error = error
              "Fallback"
            }
          }

          it "records a failed recovery probe and returns fallback" do
            allow(notifier).to receive(:notify)
            expect(traffic_recovery).to receive(:determine_color).with(config, out_metadata).and_return(Stoplight::Domain::TrafficRecovery::YELLOW)

            Timecop.freeze do
              failure = Stoplight::Failure.from_error(error)
              expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(out_metadata)
              expect(result).to eq("Fallback")
            end

            expect(@error).to eq(error)
          end
        end
      end

      context "when error is not tracked" do
        let(:fallback) { nil }
        let(:config) { super().with(skipped_errors: [error]) }

        it_behaves_like "recovery success"
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Domain::Strategies::YellowRunStrategy
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::Infrastructure::DataStore::Redis.new(redis) }

    it_behaves_like Stoplight::Domain::Strategies::YellowRunStrategy
  end
end

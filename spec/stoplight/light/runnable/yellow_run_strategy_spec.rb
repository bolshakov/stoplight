# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::Runnable::YellowRunStrategy do
  subject(:strategy) { described_class.new(config) }

  let(:config) do
    Stoplight.config_provider.provide("foo",
      data_store:,
      recovery_strategy:,
      notifiers: [notifier])
  end
  let(:notifier) { instance_double(Stoplight::Notifier::Base) }
  let(:recovery_strategy) { instance_double(Stoplight::RecoveryStrategy) }
  let(:metadata) { instance_double(Stoplight::Metadata) }

  shared_examples Stoplight::Light::Runnable::YellowRunStrategy do
    shared_examples "recovery success" do
      before do
        expect(recovery_strategy).to receive(:evaluate).with(config, metadata).and_return(recovery_result)
      end

      context "when recovery strategy returns GREEN" do
        let(:recovery_result) { Stoplight::Color::GREEN }

        context "when switched to GREEN" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(true)
          end

          it "records success, notify and returns result" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::GREEN, nil)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

            suppress(StandardError) { result }
          end
        end

        context "when not switched to GREEN" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(false)
          end

          it "records success and returns result without a notification" do
            expect(notifier).not_to receive(:notify)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

            suppress(StandardError) { result }
          end
        end
      end

      context "when recovery strategy returns RED" do
        let(:recovery_result) { Stoplight::Color::RED }

        context "when switched to RED" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
          end

          it "records success, notify and returns result" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::RED, nil)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

            suppress(StandardError) { result }
          end
        end

        context "when not switched to RED" do
          before do
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(false)
          end

          it "records success and returns result without a notification" do
            expect(notifier).not_to receive(:notify)
            expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

            suppress(StandardError) { result }
          end
        end
      end

      context "when recovery strategy returns YELLOW" do
        let(:recovery_result) { Stoplight::Color::YELLOW }

        it "records success, and returns result without a notification" do
          expect(notifier).not_to receive(:notify)
          expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

          suppress(StandardError) { result }
        end
      end

      context "when recovery strategy returns unexpected color" do
        let(:recovery_result) { :unexpected_color }

        it "raises an error" do
          expect(notifier).not_to receive(:notify)
          expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

          expect { result }.to raise_error(/recovery strategy returned an expected color/)
        end
      end
    end

    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, &code) }

      let(:code) { -> { "Success" } }
      let(:failures) { [Stoplight::Failure.from_error(StandardError.new)] }

      it_behaves_like "recovery success"

      it "returns the result" do
        expect(recovery_strategy).to receive(:evaluate).and_return(Stoplight::Color::YELLOW)
        expect(result).to eq("Success")
      end
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }

      context "when error is tracked" do
        before do
          allow(config).to receive(:track_error?).with(error).and_return(true)
        end

        context "when fallback is not provided" do
          let(:fallback) { nil }

          before do
            expect(recovery_strategy).to receive(:evaluate).with(config, metadata).and_return(recovery_result)
          end

          context "when recovery strategy returns GREEN" do
            let(:recovery_result) { Stoplight::Color::GREEN }

            context "when switched to GREEN" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::GREEN).and_return(true)
              end

              it "records failure, notify and raises an exception" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::RED, Stoplight::Color::GREEN, nil)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

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
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end

          context "when recovery strategy returns RED" do
            let(:recovery_result) { Stoplight::Color::RED }

            context "when switched to RED" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
              end

              it "records failure, notify and raises an exception" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::YELLOW, Stoplight::Color::RED, nil)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end

            context "when not switched to GREEN" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(false)
              end

              it "records failure and raises an exception without a notification" do
                expect(notifier).not_to receive(:notify)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end

          context "when recovery strategy returns YELLOW" do
            let(:recovery_result) { Stoplight::Color::YELLOW }

            it "records failure, and raises an exception without a notification" do
              expect(notifier).not_to receive(:notify)

              Timecop.freeze do
                failure = Stoplight::Failure.from_error(error)
                expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

                expect { result }.to raise_error(error)
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
            expect(recovery_strategy).to receive(:evaluate).with(config, metadata).and_return(Stoplight::Color::YELLOW)

            Timecop.freeze do
              failure = Stoplight::Failure.from_error(error)
              expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)
              expect(result).to eq("Fallback")
            end

            expect(@error).to eq(error)
          end
        end
      end

      context "when error is not tracked" do
        let(:fallback) { nil }

        before do
          allow(config).to receive(:track_error?).with(error).and_return(false)
        end

        it_behaves_like "recovery success"

        it "raises the error and record recovery success" do
          expect(recovery_strategy).to receive(:evaluate).and_return(Stoplight::Color::YELLOW)

          expect { result }.to raise_error(error)
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Light::Runnable::YellowRunStrategy
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like Stoplight::Light::Runnable::YellowRunStrategy
  end
end

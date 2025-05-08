# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::Runnable::GreenRunStrategy do
  subject(:strategy) { described_class.new(config) }

  let(:config) do
    Stoplight.config_provider.provide(
      "foo",
      data_store:,
      evaluation_strategy:,
      notifiers: [notifier]
    )
  end
  let(:notifier) { instance_double(Stoplight::Notifier::Base) }
  let(:evaluation_strategy) { instance_double(Stoplight::EvaluationStrategy) }

  shared_examples Stoplight::Light::Runnable::GreenRunStrategy do
    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, &code) }

      let(:code) { -> { "Success" } }

      it "returns result" do
        expect(data_store).to receive(:record_success).with(config)

        expect(result).to eq("Success")
      end
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }
      let(:metadata) { instance_double(Stoplight::Metadata) }

      context "when error is tracked" do
        before do
          allow(config).to receive(:track_error?).with(error).and_return(true)
        end

        context "when fallback is not provided" do
          let(:fallback) { nil }

          context "when threshold is breached" do
            before do
              expect(evaluation_strategy).to receive(:evaluate).with(config, metadata).and_return(true)
            end

            context "when transitions to red" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
              end

              it "records failure, notify and raises the error" do
                expect(notifier).to receive(:notify).with(config, Stoplight::Color::GREEN, Stoplight::Color::RED, error)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_failure).with(config, failure).and_return(metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end

            context "when does not transition to red" do
              before do
                expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(false)
              end

              it "records failure, does not notify and raises the error" do
                expect(notifier).not_to receive(:notify)

                Timecop.freeze do
                  failure = Stoplight::Failure.from_error(error)
                  expect(data_store).to receive(:record_failure).with(config, failure).and_return(metadata)

                  expect { result }.to raise_error(error)
                end
              end
            end
          end

          context "when threshold is not breached" do
            before do
              expect(evaluation_strategy).to receive(:evaluate).with(config, metadata).and_return(false)
            end

            it "records failure and raises the error without a notification" do
              expect(notifier).not_to receive(:notify)

              Timecop.freeze do
                failure = Stoplight::Failure.from_error(error)
                expect(data_store).to receive(:record_failure).with(config, failure).and_return(metadata)

                expect { result }.to raise_error(error)
              end
            end
          end
        end

        context "when fallback is provided" do
          let(:fallback) do
            ->(error) {
              @error = error
              "Fallback"
            }
          end

          before do
            expect(evaluation_strategy).to receive(:evaluate).with(config, metadata).and_return(true)
            expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Color::RED).and_return(true)
          end

          it "records failure, notify and returns the fallback" do
            expect(notifier).to receive(:notify).with(config, Stoplight::Color::GREEN, Stoplight::Color::RED, error)

            Timecop.freeze do
              failure = Stoplight::Failure.from_error(error)
              expect(data_store).to receive(:record_failure).with(config, failure).and_return(metadata)
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

        it "raises the error" do
          expect(data_store).to receive(:record_success)

          expect { result }.to raise_error(StandardError, "Test error")
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Light::Runnable::GreenRunStrategy
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like Stoplight::Light::Runnable::GreenRunStrategy
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::GreenRunStrategy do
  subject(:strategy) do
    described_class.new(
      config:,
      traffic_control:,
      data_store:,
      notifiers: [notifier]
    )
  end

  let(:config) do
    Stoplight::Domain::Config.empty.with(
      name: "foo",
      tracked_errors: [StandardError],
      skipped_errors: [],
      cool_off_time: 60,
      threshold: 3
    )
  end
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:traffic_control) { Stoplight::Domain::TrafficControl::ConsecutiveErrors.new }
  let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

  shared_examples Stoplight::Domain::Strategies::GreenRunStrategy do
    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, metadata:, &code) }

      let(:code) { -> { "Success" } }

      it "returns result" do
        expect(data_store).to receive(:record_success).with(config)

        expect(result).to eq("Success")
      end
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, metadata:, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }
      let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

      context "when error is tracked" do
        let(:config) { super().with(tracked_errors: [error]) }

        context "when fallback is not provided" do
          let(:fallback) { nil }

          context "when threshold is breached" do
            before do
              expect(traffic_control).to receive(:stop_traffic?).with(config, metadata).and_return(true)
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
              expect(traffic_control).to receive(:stop_traffic?).with(config, metadata).and_return(false)
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
            expect(traffic_control).to receive(:stop_traffic?).with(config, metadata).and_return(true)
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
        let(:config) { super().with(skipped_errors: [error]) }

        it "raises the error" do
          expect(data_store).to receive(:record_success)

          expect { result }.to raise_error(StandardError, "Test error")
        end
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Domain::Strategies::GreenRunStrategy
  end

  context "with redis data store" do
    context "when redis is available", :redis do
      let(:data_store) do
        Stoplight::Wiring::FailSafeDataStore.wrap(
          data_store: Stoplight::Infrastructure::DataStore::Redis.new(redis),
          error_notifier: ->(_) {}
        )
      end

      it_behaves_like Stoplight::Domain::Strategies::GreenRunStrategy
    end

    context "when redis is unreachable" do
      let(:data_store) do
        Stoplight::Wiring::FailSafeDataStore.wrap(
          data_store: Stoplight::Infrastructure::DataStore::Redis.new(redis),
          error_notifier: ->(_) {}
        )
      end
      let(:redis) { Redis.new(url: "redis://561922f7-6b30-49d3-8148-324922d590d2:6379/0") }

      context "when code fails with fallback" do
        subject(:result) { strategy.execute(->(e) { "whoops" }, metadata:, &code) }

        let(:error) { StandardError.new("Test error") }
        let(:code) { -> { raise error } }

        it "returns fallback" do
          expect(result).to eq("whoops")
        end
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::YellowRunStrategy do
  subject(:strategy) do
    described_class.new(
      config:,
      data_store:,
      notifiers: notifiers,
      request_tracker:
    )
  end

  let(:notifiers) { [notifier] }
  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:request_tracker) { instance_double(Stoplight::Domain::Tracker::RecoveryProbe) }

  describe "#exceute" do
    before do
      allow(strategy).to receive(:enter_recovery)
    end

    context "when code executes successfully" do
      subject(:result) { strategy.execute(nil, metadata: nil, &code) }

      let(:code) { -> { "Success" } }

      it "returns result" do
        expect(request_tracker).to receive(:record_success)

        expect(result).to eq("Success")
      end
    end

    context "when code fails" do
      subject(:result) { strategy.execute(fallback, metadata: nil, &code) }

      let(:error) { StandardError.new("Test error") }
      let(:code) { -> { raise error } }
      let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

      before do
        allow(config).to receive(:track_error?).and_return(track_error)
      end

      context "when error is tracked" do
        let(:track_error) { true }

        context "when fallback is not provided" do
          let(:fallback) { nil }

          it "records failure, notify and raises the error" do
            expect(request_tracker).to receive(:record_failure).with(error)

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

          expect { result }.to raise_error(StandardError, "Test error")
        end
      end
    end
  end

  describe "#enter_recovery" do
    subject(:enter_recovery) { strategy.__send__(:enter_recovery, metadata) }

    context "when recovery has already started" do
      let(:metadata) { instance_double(Stoplight::Domain::Metadata, recovery_started?: true) }

      it "does not send notifications" do
        expect(notifier).not_to receive(:notify)

        enter_recovery
      end
    end

    context "when recovery has not yet started" do
      let(:metadata) { instance_double(Stoplight::Domain::Metadata, recovery_started?: false) }

      it "notifies if able to transition to YELLO" do
        expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Domain::Color::YELLOW).and_return(true)
        expect(notifier).to receive(:notify).with(config, Stoplight::Domain::Color::RED, Stoplight::Domain::Color::YELLOW, nil)

        enter_recovery
      end

      it "does not notifies if unable to transition to YELLO" do
        expect(data_store).to receive(:transition_to_color).with(config, Stoplight::Domain::Color::YELLOW).and_return(false)
        expect(notifier).not_to receive(:notify)

        enter_recovery
      end
    end
  end

  describe "#==" do
    context "with the same arguments" do
      let(:other) { described_class.new(config:, data_store:, notifiers:, request_tracker:) }

      it { is_expected.to eq(other) }
    end

    context "with different config" do
      let(:other) { described_class.new(config: other_config, data_store:, notifiers:, request_tracker:) }
      let(:other_config) { instance_double(Stoplight::Domain::Config) }

      it { is_expected.not_to eq(other) }
    end

    context "with different request recorder" do
      let(:other) { described_class.new(config:, data_store:, notifiers:, request_tracker: other_request_tracker) }
      let(:other_request_tracker) { instance_double(Stoplight::Domain::Tracker::RecoveryProbe) }

      it { is_expected.not_to eq(other) }
    end

    context "with different data_store" do
      let(:other) { described_class.new(config:, data_store: other_data_store, notifiers:, request_tracker:) }
      let(:other_data_store) { instance_double(Stoplight::Domain::DataStore) }

      it { is_expected.not_to eq(other) }
    end

    context "with different notifiers" do
      let(:other) { described_class.new(config:, data_store:, notifiers: other_notifiers, request_tracker:) }
      let(:other_notifiers) { [] }

      it { is_expected.not_to eq(other) }
    end
  end
end

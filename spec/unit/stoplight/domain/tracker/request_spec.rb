# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::Request do
  subject(:request_tracker) { described_class.new(data_store:, traffic_control:, notifiers:, config:) }

  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:traffic_control) { instance_double(Stoplight::Domain::TrafficControl::Base) }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config) }

  specify "#record_success" do
    expect(data_store).to receive(:record_success).with(config)

    request_tracker.record_success
  end

  describe "#record_failure" do
    let(:exception) { KeyError.new("something went wrong") }
    let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

    before do
      allow(data_store).to receive(:record_failure).with(config, exception).and_return(metadata)
    end

    context "when traffic control decides to stop the traffic" do
      before do
        allow(traffic_control).to receive(:stop_traffic?).with(config, metadata).and_return(true)
      end

      context "when successfully transitions to RED" do
        it "sends notifications about transition" do
          allow(data_store).to receive(:transition_to_color).with(config, Stoplight::Domain::Color::RED).and_return(true)
          expect(notifier).to receive(:notify).with(config, Stoplight::Domain::Color::GREEN, Stoplight::Domain::Color::RED, exception)

          request_tracker.record_failure(exception)
        end
      end

      context "when failed to transition to RED" do
        it "does not send notification about transition" do
          allow(data_store).to receive(:transition_to_color).with(config, Stoplight::Domain::Color::RED).and_return(false)
          expect(notifier).not_to receive(:notify)

          request_tracker.record_failure(exception)
        end
      end
    end

    specify "when traffic control decides to continue the traffic flow" do
      expect(traffic_control).to receive(:stop_traffic?).with(config, metadata).and_return(false)

      request_tracker.record_failure(exception)
    end
  end

  describe "#==" do
    context "with the same arguments" do
      let(:request_tracker_2) { described_class.new(data_store:, traffic_control:, notifiers:, config:) }

      it "returns true" do
        expect(request_tracker).to eq(request_tracker_2)
      end
    end

    context "with different data_store" do
      let(:request_tracker_2) { described_class.new(data_store: data_store_2, traffic_control:, notifiers:, config:) }
      let(:data_store_2) { instance_double(Stoplight::Domain::DataStore) }

      it "returns true" do
        expect(request_tracker).not_to eq(request_tracker_2)
      end
    end

    context "with different traffic_control" do
      let(:request_tracker_2) { described_class.new(data_store:, traffic_control: traffic_control_2, notifiers:, config:) }
      let(:traffic_control_2) { instance_double(Stoplight::Domain::TrafficControl::Base) }

      it "returns true" do
        expect(request_tracker).not_to eq(request_tracker_2)
      end
    end

    context "with different notifiers" do
      let(:request_tracker_2) { described_class.new(data_store:, traffic_control:, notifiers: notifiers_2, config:) }
      let(:notifiers_2) { [] }

      it "returns true" do
        expect(request_tracker).not_to eq(request_tracker_2)
      end
    end

    context "with different config" do
      let(:request_tracker_2) { described_class.new(data_store:, traffic_control:, notifiers:, config: config_2) }
      let(:config_2) { instance_double(Stoplight::Domain::Config) }

      it "returns true" do
        expect(request_tracker).not_to eq(request_tracker_2)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::Request do
  subject(:request_tracker) { described_class.new(state_store:, traffic_control:, notifiers:, config:, metrics_store:) }

  let(:metrics_store) { instance_double(NullMetricsStore) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:traffic_control) { instance_double(NullTrafficControl) }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config, name: name) }
  let(:name) { SecureRandom.uuid }

  specify "#record_success" do
    expect(metrics_store).to receive(:record_success)

    request_tracker.record_success
  end

  describe "#record_failure" do
    let(:exception) { KeyError.new("something went wrong") }
    let(:metrics) { instance_double(Stoplight::Domain::MetricsSnapshot) }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception).and_return(metrics)
    end

    context "when traffic control decides to stop the traffic" do
      before do
        allow(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(true)
      end

      context "when successfully transitions to RED" do
        it "sends notifications about transition" do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(true)
          expect(notifier).to receive(:notify).with(have_attributes(name:), Stoplight::Color::GREEN, Stoplight::Color::RED, exception)

          request_tracker.record_failure(exception)
        end
      end

      context "when failed to transition to RED" do
        it "does not send notification about transition" do
          allow(state_store).to receive(:transition_to_color).with(Stoplight::Color::RED).and_return(false)
          expect(notifier).not_to receive(:notify)

          request_tracker.record_failure(exception)
        end
      end
    end

    specify "when traffic control decides to continue the traffic flow" do
      expect(traffic_control).to receive(:stop_traffic?).with(config, metrics).and_return(false)

      request_tracker.record_failure(exception)
    end
  end
end

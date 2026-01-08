# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::RecoveryProbe do
  subject(:recorder) { described_class.new(state_store:, traffic_recovery:, notifiers:, config:, metrics_store:) }

  let(:metrics_store) { instance_double(Stoplight::Domain::Storage::Metrics) }
  let(:state_store) { instance_double(Stoplight::Domain::Storage::State) }
  let(:traffic_recovery) { instance_double(Stoplight::Domain::TrafficRecovery::Base) }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(NullNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config) }

  shared_examples "when recover to" do |recover_to:, transition_from:, transition_to:|
    context "when recover to #{recover_to}" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::MetricsSnapshot) }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
        allow(state_store).to receive(:transition_to_color).with(transition_to)
      end

      it "sends notifications" do
        expect(metrics_store).to receive(:clear)
        expect(notifier).to receive(:notify).with(config, transition_from, transition_to, nil)

        record_probe
      end
    end
  end

  shared_examples "recovering after probe" do
    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::GREEN,
      transition_from: Stoplight::Color::YELLOW,
      transition_to: Stoplight::Color::GREEN

    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::RED,
      transition_from: Stoplight::Color::YELLOW,
      transition_to: Stoplight::Color::RED

    context "when recover to unexpected to outcome" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::MetricsSnapshot) }
      let(:recover_to) { "unexpected" }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "raises an error" do
        expect { record_probe }.to raise_error(/recovery strategy returned unexpected color/)
      end
    end

    context "when recover to YELLOW (needs more probes)" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::MetricsSnapshot) }
      let(:recover_to) { Stoplight::Domain::TrafficRecovery::YELLOW }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe).and_return(recover_to)
      end

      it "don't transition" do
        expect(state_store).not_to receive(:transition_to_color)
        expect(metrics_store).not_to receive(:clear)
        expect(notifier).not_to receive(:notify)

        record_probe
      end
    end
  end

  describe "#record_success" do
    subject(:record_probe) { recorder.record_success }

    before do
      allow(metrics_store).to receive(:record_success)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "#record_failure" do
    subject(:record_probe) { recorder.record_failure(exception) }

    let(:exception) { KeyError.new("bang") }

    before do
      allow(metrics_store).to receive(:record_failure).with(exception)
      allow(metrics_store).to receive(:metrics_snapshot).and_return(metrics_after_probe)
    end

    include_examples "recovering after probe"
  end
end

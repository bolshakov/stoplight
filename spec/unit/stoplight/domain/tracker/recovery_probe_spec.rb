# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Tracker::RecoveryProbe do
  subject(:recorder) { described_class.new(data_store:, traffic_recovery:, notifiers:, config:) }

  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:traffic_recovery) { instance_double(Stoplight::Domain::TrafficRecovery::Base) }
  let(:notifiers) { [notifier] }
  let(:notifier) { instance_double(Stoplight::Domain::StateTransitionNotifier) }
  let(:config) { instance_double(Stoplight::Domain::Config) }

  shared_examples "when recover to" do |recover_to:, transition_from:, transition_to:|
    context "when recover to #{recover_to}" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::Metrics) }
      let(:state_snapshot_after_probe) { instance_double(Stoplight::Domain::StateSnapshot) }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe, state_snapshot_after_probe).and_return(recover_to)
        allow(data_store).to receive(:transition_to_color).with(config, transition_to).and_return(transition_outcome)
      end

      context "when successfully transition to GREEN" do
        let(:transition_outcome) { true }

        it "sends notifications" do
          expect(notifier).to receive(:notify).with(config, transition_from, transition_to, nil)

          record_probe
        end
      end

      context "when does not transition to GREEN" do
        let(:transition_outcome) { false }

        it "does not send notifications" do
          expect(notifier).not_to receive(:notify)

          record_probe
        end
      end
    end
  end

  shared_examples "recovering after probe" do
    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::GREEN,
      transition_from: Stoplight::Domain::Color::YELLOW,
      transition_to: Stoplight::Domain::Color::GREEN

    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::YELLOW,
      transition_from: Stoplight::Domain::Color::RED,
      transition_to: Stoplight::Domain::Color::YELLOW

    include_examples "when recover to",
      recover_to: Stoplight::Domain::TrafficRecovery::RED,
      transition_from: Stoplight::Domain::Color::YELLOW,
      transition_to: Stoplight::Domain::Color::RED

    context "when recover to PASS" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::Metrics) }
      let(:state_snapshot_after_probe) { instance_double(Stoplight::Domain::StateSnapshot) }
      let(:recover_to) { Stoplight::Domain::TrafficRecovery::PASS }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe, state_snapshot_after_probe).and_return(recover_to)
      end

      it "does not send notifications" do
        expect(notifier).not_to receive(:notify)

        record_probe
      end
    end

    context "when recover to unexpected to outcome" do
      let(:metrics_after_probe) { instance_double(Stoplight::Domain::Metrics) }
      let(:state_snapshot_after_probe) { instance_double(Stoplight::Domain::StateSnapshot) }
      let(:recover_to) { "unexpected" }

      before do
        allow(traffic_recovery).to receive(:determine_color).with(config, metrics_after_probe, state_snapshot_after_probe).and_return(recover_to)
      end

      it "raises an error" do
        expect { record_probe }.to raise_error(/recovery strategy returned unexpected color/)
      end
    end
  end

  describe "#record_success" do
    subject(:record_probe) { recorder.record_success }

    before do
      allow(data_store).to receive(:record_recovery_probe_success).with(config)
      allow(data_store).to receive(:get_recovery_metrics).with(config).and_return(metrics_after_probe)
      allow(data_store).to receive(:get_state_snapshot).with(config).and_return(state_snapshot_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "#record_failure" do
    subject(:record_probe) { recorder.record_failure(exception) }

    let(:exception) { KeyError.new("bang") }

    before do
      allow(data_store).to receive(:record_recovery_probe_failure).with(config, exception)
      allow(data_store).to receive(:get_recovery_metrics).with(config).and_return(metrics_after_probe)
      allow(data_store).to receive(:get_state_snapshot).with(config).and_return(state_snapshot_after_probe)
    end

    include_examples "recovering after probe"
  end

  describe "#==" do
    context "with the same arguments" do
      let(:other) { described_class.new(config:, data_store:, traffic_recovery:, notifiers:) }

      it { expect(recorder).to eq(other) }
    end

    context "with different data_store" do
      let(:other) { described_class.new(config:, data_store: data_store_2, traffic_recovery:, notifiers:) }
      let(:data_store_2) { instance_double(Stoplight::Domain::DataStore) }

      it { expect(recorder).not_to eq(other) }
    end

    context "with different traffic_control" do
      let(:other) { described_class.new(config:, data_store:, traffic_recovery: traffic_recovery_2, notifiers:) }
      let(:traffic_recovery_2) { instance_double(Stoplight::Domain::TrafficRecovery::Base) }

      it { expect(recorder).not_to eq(other) }
    end

    context "with different notifiers" do
      let(:other) { described_class.new(config:, data_store:, traffic_recovery:, notifiers: notifiers_2) }
      let(:notifiers_2) { [] }

      it { expect(recorder).not_to eq(other) }
    end

    context "with different config" do
      let(:other) { described_class.new(config: config_2, data_store:, traffic_recovery:, notifiers:) }
      let(:config_2) { instance_double(Stoplight::Domain::Config) }

      it { expect(recorder).not_to eq(other) }
    end
  end
end

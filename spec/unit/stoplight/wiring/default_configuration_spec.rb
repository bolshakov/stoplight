# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::DefaultConfiguration do
  subject { default_config.to_h }
  let(:default_config) { described_class.new }

  context "when cool_off_time is set" do
    before do
      default_config.cool_off_time = 10
    end

    it { is_expected.to include(cool_off_time: 10) }
  end

  context "when threshold is set" do
    before do
      default_config.threshold = 4
    end

    it { is_expected.to include(threshold: 4) }
  end

  context "when recovery_threshold is set" do
    before do
      default_config.recovery_threshold = 4
    end

    it { is_expected.to include(recovery_threshold: 4) }
  end

  context "when window_size is set" do
    before do
      default_config.window_size = 55
    end

    it { is_expected.to include(window_size: 55) }
  end

  context "when tracked_errors is set" do
    before do
      default_config.tracked_errors = [StandardError]
    end

    it { is_expected.to include(tracked_errors: [StandardError]) }
  end

  context "when skipped_errors is set" do
    before do
      default_config.skipped_errors = [RuntimeError]
    end

    it { is_expected.to include(skipped_errors: [RuntimeError]) }
  end

  context "when error_notifier is set" do
    let(:error_notifier) { instance_double(Proc) }

    before do
      default_config.error_notifier = error_notifier
    end

    it { is_expected.to include(error_notifier:) }
  end

  context "when notifiers is set" do
    let(:notifier) { instance_double(Stoplight::Notifier::Base) }

    before do
      default_config.notifiers = [notifier]
    end

    it { is_expected.to include(notifiers: [notifier]) }
  end

  context "when notifier is appended" do
    let(:notifier) { instance_double(Stoplight::Notifier::Base) }

    before do
      default_config.notifiers += [notifier]
    end

    it { is_expected.to include(notifiers: [*Stoplight::Wiring::Default::NOTIFIERS, notifier]) }
  end

  context "when data_store is set" do
    let(:data_store) { instance_double(Stoplight::DataStore::Base) }

    before do
      default_config.data_store = data_store
    end

    it { is_expected.to include(data_store_config: data_store) }
  end

  context "when traffic_control is set" do
    let(:traffic_control) { :error_rate }

    before do
      default_config.traffic_control = traffic_control
    end

    it { is_expected.to include(traffic_control:) }
  end

  context "when traffic_recovery is set" do
    let(:traffic_recovery) { :consecutive_errors }

    before do
      default_config.traffic_recovery = traffic_recovery
    end

    it { is_expected.to include(traffic_recovery:) }
  end

  context "without any settings" do
    it "contains only default notifiers" do
      is_expected.to eq({notifiers: Stoplight::Wiring::Default::NOTIFIERS})
    end
  end
end

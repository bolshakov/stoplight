# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Light do
  let(:name) { 'test-light' }
  let(:config_base) do
    Stoplight::Light::Config.new(
      name: name,
      cool_off_time: 60,
      data_store: Stoplight::Default::DATA_STORE,
      error_notifier: Stoplight::Default::ERROR_NOTIFIER,
      notifiers: Stoplight::Default::NOTIFIERS,
      window_size: nil,
      tracked_errors: [StandardError],
      skipped_errors: [],
      traffic_recovery: Stoplight::Default::TRAFFIC_RECOVERY
    )
  end

  context 'with ErrorRate strategy and invalid threshold' do
    it 'raises ArgumentError for integer threshold' do
      config = config_base.with(threshold: 5, traffic_control: Stoplight::TrafficControl::ErrorRate.new)
      expect { described_class.new(config) }.to raise_error(ArgumentError, /float between 0.0 and 1.0/)
    end

    it 'raises ArgumentError for threshold <= 0' do
      config = config_base.with(threshold: 0, traffic_control: Stoplight::TrafficControl::ErrorRate.new)
      expect { described_class.new(config) }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for threshold >= 1' do
      config = config_base.with(threshold: 1, traffic_control: Stoplight::TrafficControl::ErrorRate.new)
      expect { described_class.new(config) }.to raise_error(ArgumentError)
    end
  end

  context 'with ConsecutiveFailures strategy and invalid threshold' do
    it 'raises ArgumentError for float threshold' do
      config = config_base.with(threshold: 0.5, traffic_control: Stoplight::TrafficControl::ConsecutiveFailures.new)
      expect { described_class.new(config) }.to raise_error(ArgumentError, /positive integer/)
    end

    it 'raises ArgumentError for threshold <= 0' do
      config = config_base.with(threshold: 0, traffic_control: Stoplight::TrafficControl::ConsecutiveFailures.new)
      expect { described_class.new(config) }.to raise_error(ArgumentError)
    end
  end

  context 'with valid configurations' do
    it 'does not raise for valid ErrorRate config' do
      config = config_base.with(threshold: 0.5, traffic_control: Stoplight::TrafficControl::ErrorRate.new)
      expect { described_class.new(config) }.not_to raise_error
    end

    it 'does not raise for valid ConsecutiveFailures config' do
      config = config_base.with(threshold: 3, traffic_control: Stoplight::TrafficControl::ConsecutiveFailures.new)
      expect { described_class.new(config) }.not_to raise_error
    end
  end
end

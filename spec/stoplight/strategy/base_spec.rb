# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Strategy::Base do
  subject(:strategy) { described_class.new(data_store) }

  let(:data_store) { instance_double(Stoplight::DataStore::Memory) }

  describe '#get_all' do
    it 'is not implemented' do
      expect { strategy.get_all(nil) }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_failures' do
    it 'is not implemented' do
      expect { strategy.get_failures(nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#record_failure' do
    it 'is not implemented' do
      expect { strategy.record_failure(nil, nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#clear_failures' do
    it 'is not implemented' do
      expect { strategy.clear_failures(nil) }
        .to raise_error(NotImplementedError)
    end
  end

  describe '#names' do
    let(:names) { ['foo'] }

    it 'delegates to the data store' do
      expect(data_store).to receive(:names).and_return(names)

      expect(strategy.names).to eq(names)
    end
  end

  describe '#get_state' do
    let(:state) { Stoplight::State::UNLOCKED }
    let(:light) { instance_double(Stoplight::Light) }

    it 'delegates to the data store' do
      expect(data_store).to receive(:get_state).with(light).and_return(state)

      expect(strategy.get_state(light)).to eq(state)
    end
  end

  describe '#set_state' do
    let(:state) { Stoplight::State::UNLOCKED }
    let(:light) { instance_double(Stoplight::Light) }

    it 'delegates to the data store' do
      expect(data_store).to receive(:set_state).with(light, state).and_return(state)

      expect(strategy.set_state(light, state)).to eq(state)
    end
  end

  describe '#clear_state' do
    let(:state) { Stoplight::State::UNLOCKED }
    let(:light) { instance_double(Stoplight::Light) }

    it 'delegates to the data store' do
      expect(data_store).to receive(:clear_state).with(light).and_return(state)

      expect(strategy.clear_state(light)).to eq(state)
    end
  end

  describe '#with_notification_lock' do
    let(:from) { Stoplight::Color::GREEN }
    let(:to) { Stoplight::Color::RED }
    let(:light) { instance_double(Stoplight::Light) }

    it 'delegates to the data store' do
      expect(data_store).to receive(:with_notification_lock).with(light, from, to).and_return(42)

      expect(strategy.with_notification_lock(light, from, to)).to eq(42)
    end
  end
end
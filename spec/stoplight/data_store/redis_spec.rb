# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'
require 'securerandom'

RSpec.describe Stoplight::DataStore::Redis do
  let(:data_store) { described_class.new(redis, redlock: redlock) }
  let(:redis) { MockRedis.new }
  let(:redlock) { instance_double(Redlock::Client) }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { SecureRandom.uuid }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::DataStore::Base
  end

  it_behaves_like 'Stoplight::DataStore::Base#names'

  it_behaves_like 'Stoplight::DataStore::Base#get_all'

  it_behaves_like 'Stoplight::DataStore::Base#get_failures' do
    shared_examples '#get_failures' do
      it 'handles invalid JSON' do
        expect(failure).to receive(:to_json).and_return('invalid JSON')

        data_store.record_failure(light, failure, window: window)
        light.with_error_notifier { |_error| }
        expect(data_store.get_failures(light, window: window).size).to eql(1)
      end
    end

    context 'without window' do
      let(:window) { nil }

      include_examples '#get_failures'
    end

    context 'with window' do
      let(:window) { 3600 }

      include_examples '#get_failures'
    end
  end

  it_behaves_like 'Stoplight::DataStore::Base#record_failures'

  describe '#clear_failures' do
    it 'returns the failures' do
      data_store.record_failure(light, failure)
      expect(data_store.clear_failures(light)).to eq([failure])
    end

    it 'clears the failures' do
      data_store.record_failure(light, failure)
      data_store.clear_failures(light)
      expect(data_store.get_failures(light)).to eql([])
    end
  end

  describe '#get_state' do
    it 'is initially unlocked' do
      expect(data_store.get_state(light)).to eql(Stoplight::State::UNLOCKED)
    end
  end

  describe '#set_state' do
    it 'returns the state' do
      state = 'state'
      expect(data_store.set_state(light, state)).to eql(state)
    end

    it 'persists the state' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.get_state(light)).to eql(state)
    end
  end

  describe '#clear_state' do
    it 'returns the state' do
      state = 'state'
      data_store.set_state(light, state)
      expect(data_store.clear_state(light)).to eql(state)
    end

    it 'clears the state' do
      state = 'state'
      data_store.set_state(light, state)
      data_store.clear_state(light)
      expect(data_store.get_state(light)).to eql(Stoplight::State::UNLOCKED)
    end
  end

  describe '#with_notification_lock' do
    let(:lock_key) { "stoplight:v4:notification_lock:#{name}" }

    before do
      allow(redlock).to receive(:lock).with(lock_key, 2_000).and_yield
    end

    context 'when notification is already sent' do
      before do
        data_store.with_notification_lock(light, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
      end

      it 'does not yield passed block' do
        expect do |b|
          data_store.with_notification_lock(light, Stoplight::Color::GREEN, Stoplight::Color::RED, &b)
        end.not_to yield_control
      end
    end

    context 'when notification is not already sent' do
      before do
        data_store.with_notification_lock(light, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
      end

      it 'yields passed block' do
        expect do |b|
          data_store.with_notification_lock(light, Stoplight::Color::RED, Stoplight::Color::GREEN, &b)
        end.to yield_control
      end
    end
  end
end

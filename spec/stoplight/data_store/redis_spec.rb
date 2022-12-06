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

  describe '#names' do
    it 'is initially empty' do
      expect(data_store.names).to eql([])
    end

    it 'contains the name of a light with a failure' do
      data_store.record_failure(light, failure)
      expect(data_store.names).to eql([light.name])
    end

    it 'contains the name of a light with a set state' do
      data_store.set_state(light, Stoplight::State::UNLOCKED)
      expect(data_store.names).to eql([light.name])
    end

    it 'does not duplicate names' do
      data_store.record_failure(light, failure)
      data_store.set_state(light, Stoplight::State::UNLOCKED)
      expect(data_store.names).to eql([light.name])
    end

    it 'supports names containing colons' do
      light = Stoplight::Light.new('http://api.example.com/some/action')
      data_store.record_failure(light, failure)
      expect(data_store.names).to eql([light.name])
    end
  end

  describe '#get_all' do
    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)
      expect(failures).to eql([])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end

  describe '#get_failures' do
    shared_examples '#get_failures' do
      it 'is initially empty' do
        expect(data_store.get_failures(light, window: window)).to eql([])
      end

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

      it 'returns failures' do
        data_store.record_failure(light, failure)

        expect(data_store.get_failures(light)).to contain_exactly(failure)
      end
    end

    context 'with window' do
      let(:window) { 3600 }

      include_examples '#get_failures'

      it 'returns failures withing given window' do
        data_store.record_failure(light, failure, window: window)
        old_failure = Stoplight::Failure.new('class', 'old failure', Time.new - window - 1)
        data_store.record_failure(light, old_failure, window: window)

        expect(data_store.get_failures(light, window: window)).to contain_exactly(failure)
      end
    end
  end

  describe '#record_failure' do
    shared_examples '#record_failure' do
      it 'returns the number of failures' do
        expect(data_store.record_failure(light, failure, window: window)).to eql(1)
      end

      it 'persists the failure' do
        data_store.record_failure(light, failure)
        expect(data_store.get_failures(light)).to contain_exactly(failure)
      end

      it 'stores more recent failures at the head' do
        data_store.record_failure(light, failure, window: window)
        other = Stoplight::Failure.new('class', 'message 2', Time.new - 10)
        data_store.record_failure(light, other, window: window)
        expect(data_store.get_failures(light, window: window)).to eq([other, failure])
      end

      it 'limits the number of stored failures' do
        light.with_threshold(1)
        data_store.record_failure(light, failure, window: window)
        other = Stoplight::Failure.new('class', 'message 2', Time.new - 10)
        data_store.record_failure(light, other, window: window)
        expect(data_store.get_failures(light, window: window)).to contain_exactly(failure)
      end
    end

    context 'without a window' do
      let(:window) { nil }

      include_examples '#record_failure'
    end

    context 'with a window' do
      let(:window) { 3600 }

      include_examples '#record_failure'

      it 'stores failures only withing window length' do
        data_store.record_failure(light, failure, window: window)
        other = Stoplight::Failure.new('class', 'message 2', Time.new - window - 1)
        data_store.record_failure(light, other, window: window)
        expect(data_store.get_failures(light, window: window)).to contain_exactly(failure)
      end
    end
  end

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

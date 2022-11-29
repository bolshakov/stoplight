# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'

RSpec.describe Stoplight::DataStore::Redis do
  let(:data_store) { described_class.new(redis) }
  let(:redis) { MockRedis.new }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::DataStore::Base
  end

  describe 'on initialization' do
    let(:notification_collection_namespace) { 'stoplight:notification_locks' }
    let(:notification_locks_namespace) { 'stoplight:notification_lock' }
    let(:test_light_name) { 'test-light' }

    before do
      redis.set("#{notification_locks_namespace}:#{test_light_name}", 1)
      redis.sadd(notification_collection_namespace, "#{notification_locks_namespace}:#{test_light_name}")
      described_class.new(redis)
    end

    it 'cleans up notification locks collection' do
      expect(redis.get("#{notification_locks_namespace}:#{test_light_name}")).to be_nil
    end
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
    it 'is initially empty' do
      expect(data_store.get_failures(light)).to eql([])
    end

    it 'handles invalid JSON' do
      expect(redis.keys.size).to eql(0)
      data_store.record_failure(light, failure)
      expect(redis.keys.size).to eql(1)
      redis.lset(redis.keys.first, 0, 'invalid JSON')
      light.with_error_notifier { |_error| }
      expect(data_store.get_failures(light).size).to eql(1)
    end
  end

  describe '#record_failure' do
    it 'returns the number of failures' do
      expect(data_store.record_failure(light, failure)).to eql(1)
    end

    it 'persists the failure' do
      data_store.record_failure(light, failure)
      expect(data_store.get_failures(light)).to eq([failure])
    end

    it 'stores more recent failures at the head' do
      data_store.record_failure(light, failure)
      other = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, other)
      expect(data_store.get_failures(light)).to eq([other, failure])
    end

    it 'limits the number of stored failures' do
      light.with_threshold(1)
      data_store.record_failure(light, failure)
      other = Stoplight::Failure.new('class', 'message 2', Time.new)
      data_store.record_failure(light, other)
      expect(data_store.get_failures(light)).to eq([other])
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
    let(:notification_locks_namespace) { 'stoplight:notification_lock' }
    let(:notification_collection_namespace) { 'stoplight:notification_locks' }

    context 'notification lock was not yet set' do
      it 'yields passed block' do
        expect { |b| data_store.with_notification_lock(light, &b) }.to yield_control
      end

      it 'sets notification lock key' do
        data_store.with_notification_lock(light) {}

        expect(redis.get("#{notification_locks_namespace}:#{light.name}")).to eq '1'
      end

      it 'adds lock to notification locks collection' do
        data_store.with_notification_lock(light) {}

        expect(redis.smembers(notification_collection_namespace))
          .to include "#{notification_locks_namespace}:#{light.name}"
      end
    end

    context 'notification lock was already set' do
      before { redis.set("#{notification_locks_namespace}:#{light.name}", 1) }

      it 'does not yield passed block' do
        expect { |b| data_store.with_notification_lock(light, &b) }.to_not yield_control
      end
    end
  end

  describe '#with_lock_cleanup' do
    let(:notification_locks_namespace) { 'stoplight:notification_lock' }
    let(:notification_collection_namespace) { 'stoplight:notification_locks' }

    before do
      redis.set("#{notification_locks_namespace}:#{light.name}", 1)
      redis.sadd(notification_collection_namespace, "#{notification_locks_namespace}:#{light.name}")
    end

    it 'removes notification lock' do
      data_store.with_lock_cleanup(light) {}

      expect(redis.exists?("#{notification_locks_namespace}:#{light.name}")).to be_falsey
    end

    it 'removes lock from notification locks collection' do
      data_store.with_lock_cleanup(light) {}

      expect(redis.smembers(notification_collection_namespace))
        .to_not include "#{notification_locks_namespace}:#{light.name}"
    end

    it 'yields passed block' do
      expect { |b| data_store.with_lock_cleanup(light, &b) }.to yield_control
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::DataStore::Memory do
  let(:data_store) { described_class.new }
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::DataStore::Base
  end

  it_behaves_like 'Stoplight::DataStore::Base#names'

  it_behaves_like 'Stoplight::DataStore::Base#get_all'

  it_behaves_like 'Stoplight::DataStore::Base#get_failures'

  it_behaves_like 'Stoplight::DataStore::Base#record_failures'

  describe '#clear_failures' do
    it 'returns the failures' do
      data_store.record_failure(light, failure)
      expect(data_store.clear_failures(light)).to eql([failure])
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

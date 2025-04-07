# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#with_notification_lock' do
  context 'when notification is already sent' do
    before do
      data_store.with_notification_lock(config, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
    end

    it 'does not yield passed block' do
      expect do |b|
        data_store.with_notification_lock(config, Stoplight::Color::GREEN, Stoplight::Color::RED, &b)
      end.not_to yield_control
    end
  end

  context 'when notification is not already sent' do
    before do
      data_store.with_notification_lock(config, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
    end

    it 'yields passed block' do
      expect do |b|
        data_store.with_notification_lock(config, Stoplight::Color::RED, Stoplight::Color::GREEN, &b)
      end.to yield_control
    end
  end
end

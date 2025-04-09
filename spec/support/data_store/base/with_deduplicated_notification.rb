# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#with_deduplicated_notification' do
  context 'when notification is already sent' do
    before do
      data_store.with_deduplicated_notification(config, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
    end

    it 'does not yield passed block' do
      expect do |b|
        data_store.with_deduplicated_notification(config, Stoplight::Color::GREEN, Stoplight::Color::RED, &b)
      end.not_to yield_control
    end
  end

  context 'when notification is not already sent' do
    before do
      data_store.with_deduplicated_notification(config, Stoplight::Color::GREEN, Stoplight::Color::RED) {}
    end

    it 'yields passed block' do
      expect do |b|
        data_store.with_deduplicated_notification(config, Stoplight::Color::RED, Stoplight::Color::GREEN, &b)
      end.to yield_control
    end
  end

  context 'when handling concurrent access' do
    it 'ensures atomicity under concurrent conditions' do
      expect do |b|
        threads = 100.times.map do
          Thread.new do
            data_store.with_deduplicated_notification(config, Stoplight::Color::GREEN, Stoplight::Color::RED, &b)
          end
        end
        threads.each(&:join)
      end.to yield_control.once
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

RSpec.describe Stoplight::Configuration do
  subject(:configuration) { described_class.new(name) }

  let(:name) { SecureRandom.uuid }

  describe '#initializer' do
    it 'set to defaults' do
      is_expected.to have_attributes(
        name: name,
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        threshold: Stoplight::Default::THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        data_store: described_class.default_data_store,
        notifiers: described_class.default_notifiers
      )
    end
  end

  shared_examples 'configurable attribute' do |attribute|
    subject(:new_configuration) do
      configuration.__send__("with_#{attribute}", __send__(attribute))
    end

    it 'returns a new instance of configuration' do
      expect(new_configuration).not_to eq(configuration)
      expect(new_configuration.__send__(attribute)).to eq(__send__(attribute))
    end

    it 'does not change original configuration' do
      expect { new_configuration }.not_to change(configuration, attribute)
    end
  end

  describe '#with_data_store' do
    let(:data_store) { instance_double(Stoplight::DataStore::Redis) }

    include_examples 'configurable attribute', :data_store
  end

  describe '#with_data_store' do
    let(:cool_off_time) { 1_000 }

    include_examples 'configurable attribute', :cool_off_time
  end

  describe '#with_threshold' do
    let(:threshold) { 1_000 }

    include_examples 'configurable attribute', :threshold
  end

  describe '#with_window_size' do
    let(:window_size) { 1_000 }

    include_examples 'configurable attribute', :window_size
  end

  describe '#with_notifiers' do
    let(:notifiers) { 1_000 }

    include_examples 'configurable attribute', :notifiers
  end

  describe '#with_error_handler' do
    subject(:light) { configuration.with_error_handler(&error_handler) }

    let(:error_handler) { ->(error, handle) {} }

    it 'returns an instance of the Light class with this configuration set' do
      expect(light.configuration).to be(configuration)
      expect(light.error_handler).to eq(error_handler)
    end
  end

  describe '#with_error_notifier' do
    subject(:light) { configuration.with_error_notifier(&error_notifier) }

    let(:error_notifier) { ->(error) {} }

    it 'returns an instance of the Light class with this configuration set' do
      expect(light.configuration).to be(configuration)
      expect(light.error_notifier).to eq(error_notifier)
    end
  end

  describe '#with_error_notifier' do
    subject(:light) { configuration.with_fallback(&fallback) }

    let(:fallback) { ->(error) {} }

    it 'returns an instance of the Light class with this configuration set' do
      expect(light.configuration).to be(configuration)
      expect(light.fallback).to eq(fallback)
    end
  end

  describe '#run' do
    it 'yields the block' do
      expect do |code|
        configuration.run(&code)
      end.to yield_control
    end
  end

  describe '#lock, #unlock, #color' do
    context 'when the light is not locked' do
      it 'locks the light' do
        expect { configuration.lock(Stoplight::Color::RED) }
          .to change(configuration, :color)
          .from(Stoplight::Color::GREEN)
          .to(Stoplight::Color::RED)
      end
    end

    context 'when the light is locked' do
      before do
        configuration.lock(Stoplight::Color::RED)
      end

      it 'locks the light' do
        expect { configuration.unlock }
          .to change(configuration, :color)
          .from(Stoplight::Color::RED)
          .to(Stoplight::Color::GREEN)
      end
    end
  end
end

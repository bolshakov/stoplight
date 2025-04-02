# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Stoplight::Light do
  let(:light) { Stoplight(name).build }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:code) { -> {} }

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  describe '#cool_off_time' do
    it 'is initially the default' do
      expect(light.cool_off_time).to eql(Stoplight::Default::COOL_OFF_TIME)
    end
  end

  describe '#data_store' do
    it 'is initially the default' do
      expect(light.data_store).to eql(Stoplight.default_data_store)
    end
  end

  describe '#error_handler' do
    it 'it initially the default' do
      expect(light.error_handler).to eql(Stoplight::Default::ERROR_HANDLER)
    end
  end

  describe '#error_notifier' do
    it 'it initially the default' do
      expect(light.error_notifier)
        .to eql(Stoplight.default_error_notifier)
    end
  end

  describe '#fallback' do
    it 'is initially the default' do
      expect(light.fallback).to eql(Stoplight::Default::FALLBACK)
    end
  end

  describe '#name' do
    it 'reads the name' do
      expect(light.name).to eql(name)
    end
  end

  describe '#notifiers' do
    it 'is initially the default' do
      expect(light.notifiers).to eql(Stoplight.default_notifiers)
    end
  end

  describe '#threshold' do
    it 'is initially the default' do
      expect(light.threshold).to eql(Stoplight::Default::THRESHOLD)
    end
  end

  describe '#window_size' do
    it 'is initially the default' do
      expect(light.window_size).to eql(Stoplight::Default::WINDOW_SIZE)
    end
  end

  describe '#with_error_handler' do
    it 'sets the error handler' do
      error_handler = ->(_, _) {}
      light.with_error_handler(&error_handler)
      expect(light.error_handler).to eql(error_handler)
    end
  end

  describe '#with_error_notifier' do
    it 'sets the error notifier' do
      error_notifier = ->(_) {}
      light.with_error_notifier(&error_notifier)
      expect(light.error_notifier).to eql(error_notifier)
    end
  end

  describe '#with_fallback' do
    it 'sets the fallback' do
      fallback = ->(_) {}
      light.with_fallback(&fallback)
      expect(light.fallback).to eql(fallback)
    end
  end

  it_behaves_like Stoplight::Configurable do
    let(:configurable) { described_class.new('foo', configuration) }
  end
end

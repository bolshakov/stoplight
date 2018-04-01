# coding: utf-8

require 'spec_helper'

# require 'dogapi'
module Dogapi
  class Client
    def initialize(*)
    end
  end
end

RSpec.describe Stoplight::Notifier::DataDogServiceCheck do
  prefix = 'stoplight'
  host = 'myhostname'
  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::Notifier::Base
  end

  describe '#formatter' do
    it 'is initially the default' do
      expect(described_class.new(nil, host, prefix).formatter).to eql(
        Stoplight::Default::FORMATTER
      )
    end

    it 'reads the formatter' do
      formatter = proc {}
      expect(described_class
        .new(nil, host, prefix, formatter).formatter)
        .to eql(formatter)
    end
  end

  describe '#options' do
    it 'is intiially the default' do
      expect(described_class.new(nil, host, prefix).options).to eql(
        Stoplight::Notifier::DataDogServiceCheck::DEFAULT_OPTIONS
      )
    end

    it 'reads the options' do
      options = { key: :value }
      expect(described_class
        .new(nil, host, prefix, nil, options).options)
        .to eql(
          Stoplight::Notifier::DataDogServiceCheck::DEFAULT_OPTIONS
          .merge(options)
        )
    end
  end

  describe '#dogapi' do
    it 'reads the Dogapi client' do
      dogapi = Dogapi::Client.new('API token')
      expect(described_class.new(dogapi, host, prefix).dogapi)
        .to eql(dogapi)
    end
  end

  describe '#host' do
    it 'reads the host' do
      expect(described_class.new(nil, host, prefix).host).to eql(host)
    end
  end

  describe '#prefix' do
    it 'reads the prefix' do
      expect(described_class.new(nil, host, prefix).prefix).to eql(prefix)
    end
  end

  describe '#check' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:notifier) { described_class.new(nil, host, prefix) }

    it 'returns the prefix combined with the stoplight name' do
      expect(notifier.check(light)).to eql(prefix + '.' + name)
    end
  end

  describe '#get_status' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:notifier) { described_class.new(nil, host, prefix) }

    it 'returns 0 for a working stoplight' do
      expect(notifier.get_status(light.color)).to eql(0)
    end

    context 'when the stoplight is yellow' do
      it 'returns 1' do
        expect(notifier.get_status('yellow')).to eql(1)
      end
    end

    context 'when the stoplight is red' do
      let(:light) { Stoplight::Light.new(name, &code).with_threshold(0) }
      let(:code) { -> { 0 / 0 } }
      it 'returns 2' do
        expect(notifier.get_status(light.color)).to eql(2)
      end
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { described_class.new(dogapi, host, prefix) }
    let(:dogapi) { double(Dogapi::Client) }
    let(:api_key) { ('a'..'z').to_a.shuffle.join }

    before do
      allow(dogapi).to receive(:service_check)
    end

    it 'returns the message' do
      error = nil
      expect(notifier.notify(light, from_color, to_color, error))
        .to eql(notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'returns the message with an error' do
      error = ZeroDivisionError.new('divide by 0')
      expect(notifier.notify(light, from_color, to_color, error))
        .to eql(notifier.formatter.call(light, from_color, to_color, error))
    end
  end
end

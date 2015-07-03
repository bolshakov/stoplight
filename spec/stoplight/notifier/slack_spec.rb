# coding: utf-8

require 'spec_helper'
require 'slack-notifier'

RSpec.describe Stoplight::Notifier::Slack do
  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::Notifier::Base
  end

  describe '#formatter' do
    it 'is initially the default' do
      expect(described_class.new(nil).formatter).to eql(Stoplight::Default::FORMATTER)
    end

    it 'reads the formatter' do
      formatter = proc {}
      expect(described_class.new(nil, formatter).formatter).to eql(formatter)
    end
  end

  describe '#slack_notifier' do
    it 'reads Slack::Notifier client' do
      slack = Slack::Notifier.new('WEBHOOK_URL')
      expect(described_class.new(slack).slack).to eql(slack)
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { described_class.new(slack) }
    let(:slack) { double(Slack::Notifier) }

    before do
      expect(slack).to receive(:ping).with(kind_of(String))
    end

    it 'returns the message' do
      error = nil
      expect(notifier.notify(light, from_color, to_color, error))
        .to eql(notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'returns the message with an error' do
      error = ZeroDivisionError.new('divided by 0')
      expect(notifier.notify(light, from_color, to_color, error))
        .to eql(notifier.formatter.call(light, from_color, to_color, error))
    end
  end
end

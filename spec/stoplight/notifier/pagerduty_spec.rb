# coding: utf-8

require 'spec_helper'
require 'pagerduty'

RSpec.describe Stoplight::Notifier::Pagerduty do
  it_behaves_like 'a generic notifier'

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::Notifier::Base
  end

  describe '#pagerduty' do
    it 'reads Pagerduty client' do
      pagerduty = Pagerduty.new('WEBHOOK_URL')
      expect(described_class.new(pagerduty).pagerduty).to eql(pagerduty)
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { described_class.new(pagerduty) }
    let(:pagerduty) { double(Pagerduty).as_null_object }

    it 'pings Pagerduty' do
      error = nil
      message = notifier.formatter.call(light, from_color, to_color, error)
      expect(pagerduty).to receive(:trigger).with(message)
      notifier.notify(light, from_color, to_color, error)
    end
  end
end

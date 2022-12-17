# frozen_string_literal: true

require 'spec_helper'
require 'logger'
require 'stringio'
require 'stoplight/rspec'

RSpec.describe Stoplight::Notifier::Logger do
  it_behaves_like 'a generic notifier'

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  it 'is a subclass of Base' do
    expect(described_class).to be < Stoplight::Notifier::Base
  end

  describe '#formatter' do
    it 'is initially the default' do
      expect(described_class.new(nil, nil).formatter)
        .to eql(Stoplight::Default::FORMATTER)
    end

    it 'reads the formatter' do
      formatter = proc {}
      expect(described_class.new(nil, formatter).formatter)
        .to eql(formatter)
    end
  end

  describe '#logger' do
    it 'reads the logger' do
      logger = Logger.new(StringIO.new)
      expect(described_class.new(logger, nil).logger)
        .to eql(logger)
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { described_class.new(Logger.new(io)) }
    let(:io) { StringIO.new }

    before do
      notifier.notify(light, from_color, to_color, error)
    end

    subject(:result) { io.string }

    context 'when no error given' do
      let(:error) { nil }

      it 'logs message' do
        expect(result).to match(/.+#{message}/)
      end
    end

    context 'when message with an error given' do
      let(:error) { ZeroDivisionError.new('divided by 0') }

      it 'logs message' do
        expect(result).to match(/.+#{message}/)
      end
    end

    def message
      notifier.formatter.call(light, from_color, to_color, error)
    end
  end
end

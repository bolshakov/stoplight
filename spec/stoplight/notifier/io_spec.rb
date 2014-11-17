# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Notifier::IO do
  it 'is a class' do
    Stoplight::Notifier::IO.must_be_kind_of(Module)
  end

  it 'is a subclass of Base' do
    Stoplight::Notifier::IO.must_be(:<, Stoplight::Notifier::Base)
  end

  describe '#formatter' do
    it 'is initially the default' do
      assert_equal(
        Stoplight::Notifier::IO.new(nil).formatter,
        Stoplight::Default::FORMATTER)
    end

    it 'reads the formatter' do
      formatter = proc {}
      assert_equal(
        Stoplight::Notifier::IO.new(nil, formatter).formatter, formatter)
    end
  end

  describe '#io' do
    it 'reads the IO' do
      io = StringIO.new
      Stoplight::Notifier::IO.new(io).io.must_equal(io)
    end
  end

  describe '#notify' do
    let(:light) { Stoplight::Light.new(name, &code) }
    let(:name) { ('a'..'z').to_a.shuffle.join }
    let(:code) { -> {} }
    let(:from_color) { Stoplight::Color::GREEN }
    let(:to_color) { Stoplight::Color::RED }
    let(:notifier) { Stoplight::Notifier::IO.new(io) }
    let(:io) { StringIO.new }

    it 'returns the message' do
      error = nil
      notifier.notify(light, from_color, to_color, error).must_equal(
        notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'returns the message with an error' do
      error = ZeroDivisionError.new('divided by 0')
      notifier.notify(light, from_color, to_color, error).must_equal(
        notifier.formatter.call(light, from_color, to_color, error))
    end

    it 'writes the message' do
      error = nil
      notifier.notify(light, from_color, to_color, error)
      io.string.must_equal(
        notifier.formatter.call(light, from_color, to_color, error) + "\n")
    end
  end
end

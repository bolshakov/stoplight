# coding: utf-8

require 'json'
require 'minitest/spec'
require 'stoplight'
require 'time'

describe Stoplight::Failure do
  let(:error) { ZeroDivisionError.new('divided by 0') }
  let(:error_class) { error.class.name }
  let(:error_message) { error.message }
  let(:time) { Time.new(2001, 2, 3, 4, 5, 6, '+07:08') }
  let(:json) do
    JSON.generate(
      error: { class: error_class, message: error_message },
      time: time.strftime('%Y-%m-%dT%H:%M:%S.%N%:z'))
  end

  it 'is a class' do
    Stoplight::Failure.must_be_kind_of(Class)
  end

  describe '.from_error' do
    it 'creates a failure' do
      failure = Stoplight::Failure.from_error(error)
      failure.error_class.must_equal(error_class)
      failure.error_message.must_equal(error_message)
      failure.time.must_be_close_to(Time.new)
    end
  end

  describe '.from_json' do
    it 'parses JSON' do
      failure = Stoplight::Failure.from_json(json)
      failure.error_class.must_equal(error_class)
      failure.error_message.must_equal(error_message)
      failure.time.must_equal(time)
    end
  end

  describe '#==' do
    it 'is true when they are equal' do
      failure = Stoplight::Failure.new(error_class, error_message, time)
      other = Stoplight::Failure.new(error_class, error_message, time)
      failure.must_equal(other)
    end

    it 'is false when they have different error classes' do
      failure = Stoplight::Failure.new(error_class, error_message, time)
      other = Stoplight::Failure.new(nil, error_message, time)
      failure.wont_equal(other)
    end

    it 'is false when they have different error messages' do
      failure = Stoplight::Failure.new(error_class, error_message, time)
      other = Stoplight::Failure.new(error_class, nil, time)
      failure.wont_equal(other)
    end

    it 'is false when they have different times' do
      failure = Stoplight::Failure.new(error_class, error_message, time)
      other = Stoplight::Failure.new(error_class, error_message, nil)
      failure.wont_equal(other)
    end
  end

  describe '#error_class' do
    it 'reads the error class' do
      Stoplight::Failure.new(error_class, nil, nil).error_class
        .must_equal(error_class)
    end
  end

  describe '#error_message' do
    it 'reads the error message' do
      Stoplight::Failure.new(nil, error_message, nil).error_message
        .must_equal(error_message)
    end
  end

  describe '#time' do
    it 'reads the time' do
      Stoplight::Failure.new(nil, nil, time).time.must_equal(time)
    end
  end

  describe '#to_json' do
    it 'generates JSON' do
      Stoplight::Failure.new(error_class, error_message, time).to_json
        .must_equal(json)
    end
  end
end

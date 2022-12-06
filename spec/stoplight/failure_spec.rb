# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Failure do
  let(:error) { ZeroDivisionError.new('divided by 0') }
  let(:error_class) { error.class.name }
  let(:error_message) { error.message }
  let(:time) { Time.new(2001, 2, 3, 4, 5, 6, '+07:08') }
  let(:uuid) { SecureRandom.uuid }
  let(:json) do
    JSON.generate(
      error: { class: error_class, message: error_message },
      time: time.strftime('%Y-%m-%dT%H:%M:%S.%N%:z'),
      uuid: uuid
    )
  end

  it 'is a class' do
    expect(described_class).to be_a(Class)
  end

  describe '.from_error' do
    it 'creates a failure' do
      Timecop.freeze do
        failure = described_class.from_error(error)
        expect(failure.error_class).to eql(error_class)
        expect(failure.error_message).to eql(error_message)
        expect(failure.time).to eql(Time.new)
      end
    end
  end

  describe '.from_json' do
    it 'parses JSON' do
      failure = described_class.from_json(json)
      expect(failure.error_class).to eql(error_class)
      expect(failure.error_message).to eql(error_message)
      expect(failure.time).to eql(time)
      expect(failure.uuid).to eql(uuid)
    end
  end

  describe '#==' do
    it 'is true when they are equal' do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, error_message, time)
      expect(failure).to eq(other)
    end

    it 'is false when they have different error classes' do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(nil, error_message, time)
      expect(failure).to_not eq(other)
    end

    it 'is false when they have different error messages' do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, nil, time)
      expect(failure).to_not eq(other)
    end

    it 'is false when they have different times' do
      failure = described_class.new(error_class, error_message, time)
      other = described_class.new(error_class, error_message, nil)
      expect(failure).to_not eq(other)
    end
  end

  describe '#error_class' do
    it 'reads the error class' do
      expect(described_class.new(error_class, nil, nil).error_class)
        .to eql(error_class)
    end
  end

  describe '#error_message' do
    it 'reads the error message' do
      expect(described_class.new(nil, error_message, nil).error_message)
        .to eql(error_message)
    end
  end

  describe '#time' do
    it 'reads the time' do
      expect(described_class.new(nil, nil, time).time).to eql(time)
    end
  end

  describe '#to_json' do
    let(:failure) { described_class.new(error_class, error_message, time, uuid) }

    context 'without options' do
      subject(:serialized_failure) { failure.to_json }

      it 'generates JSON' do
        expect(serialized_failure).to eql(json)
      end
    end

    context 'without options' do
      subject(:serialized_failure) { failure.to_json({}) }

      it 'generates JSON' do
        expect(serialized_failure).to eql(json)
      end
    end
  end

  describe '::TIME_FORMAT' do
    it 'is a string' do
      expect(described_class::TIME_FORMAT).to be_a(String)
    end

    it 'is frozen' do
      expect(described_class::TIME_FORMAT).to be_frozen
    end
  end
end

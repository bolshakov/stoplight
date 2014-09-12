# coding: utf-8

require 'spec_helper'

describe Stoplight::Failure do
  subject(:failure) { described_class.new(error_class, error_message, time) }
  let(:error_class) { SecureRandom.hex }
  let(:error_message) { SecureRandom.hex }
  let(:time) { Time.now }

  describe '.create' do
    subject(:result) { described_class.create(error) }
    let(:error) { error_class.new(error_message) }
    let(:error_class) { Class.new(StandardError) }

    it 'creates a failure' do
      expect(result).to be_a(Stoplight::Failure)
      expect(result.error_class).to eql(error.class.name)
      expect(result.error_message).to eql(error.message)
      expect(result.time).to be_within(1).of(Time.now)
    end
  end

  describe '.from_json' do
    subject(:result) { described_class.from_json(json) }
    let(:json) { failure.to_json }

    it 'can be round-tripped' do
      expect(result.error_class).to eq(failure.error_class)
      expect(result.error_message).to eq(failure.error_message)
      expect(result.time).to be_within(1).of(failure.time)
    end

    context 'with invalid JSON' do
      let(:json) { nil }

      it 'does not raise an error' do
        expect { result }.to_not raise_error
      end

      it 'returns a self-describing invalid failure' do
        expect(result.error_class).to eq('Stoplight::Error::InvalidFailure')
        expect(result.error_message).to end_with('nil into String')
        expect(result.time).to be_within(1).of(Time.now)
      end
    end
  end

  describe '#initialize' do
    it 'sets the error class' do
      expect(failure.error_class).to eql(error_class)
    end

    it 'sets the error message' do
      expect(failure.error_message).to eql(error_message)
    end

    it 'sets the time' do
      expect(failure.time).to eql(time)
    end

    context 'without a time' do
      let(:time) { nil }

      it 'uses the default time' do
        expect(failure.time).to be_within(1).of(Time.now)
      end
    end
  end

  describe '#to_json' do
    subject(:json) { failure.to_json }
    let(:data) { JSON.load(json) }
    let(:time) { Time.utc(2001, 2, 3, 4, 5, 6) }

    it 'converts to JSON' do
      expect(data['error']['class']).to eql(error_class)
      expect(data['error']['message']).to eql(error_message)
      expect(data['time']).to eql('2001-02-03T04:05:06+00:00')
    end
  end
end

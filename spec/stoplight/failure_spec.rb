# coding: utf-8

require 'spec_helper'

describe Stoplight::Failure do
  subject(:failure) { described_class.new(error, time) }
  let(:error) { error_class.new(error_message) }
  let(:error_class) { StandardError }
  let(:error_message) { SecureRandom.hex }
  let(:time) { Time.now }

  describe '.from_json' do
    subject(:result) { described_class.from_json(json) }
    let(:json) { failure.to_json }

    it do
      expect(result.error).to eq(failure.error)
      expect(result.time).to be_within(1).of(failure.time)
    end
  end

  describe '#initialize' do
    it 'sets the error' do
      expect(failure.error).to eql(error)
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

    it 'converts to JSON' do
      expect(data['error']).to eql(error.inspect)
      expect(data['time']).to eql(time.inspect)
    end
  end
end

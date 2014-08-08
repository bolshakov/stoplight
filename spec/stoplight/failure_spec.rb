# coding: utf-8

require 'spec_helper'

describe Stoplight::Failure do
  let(:error) { double }

  subject(:failure) { described_class.new(error) }

  describe '#to_json' do
    let(:json) { JSON.parse(result) }

    subject(:result) { failure.to_json }

    it 'includes the error' do
      expect(json['error']).to eql(error.inspect)
    end

    it 'includes the time' do
      expect(json['time']).to eql(Time.now.to_s)
    end
  end
end

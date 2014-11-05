# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Redis do
  subject(:data_store) { described_class.new(redis) }
  let(:redis) { Redis.new }

  it_behaves_like 'a data store'

  context 'with a failing connection' do
    let(:name) { SecureRandom.hex }
    let(:error) { Redis::BaseConnectionError.new(message) }
    let(:message) { SecureRandom.hex }

    before { allow(redis).to receive(:hget).and_raise(error) }

    it 'reraises the error' do
      expect { data_store.sync(name) }
        .to raise_error(Stoplight::Error::BadDataStore)
    end

    it 'sets the message' do
      rescued =
        begin
          data_store.sync(name)
        rescue Stoplight::Error::BadDataStore => e
          expect(e.message).to eql(message)
          true
        end
      expect(rescued).to eql(true)
    end

    it 'sets the cause' do
      rescued =
        begin
          data_store.sync(name)
        rescue Stoplight::Error::BadDataStore => e
          expect(e.cause).to eql(error)
          true
        end
      expect(rescued).to eql(true)
    end
  end
end

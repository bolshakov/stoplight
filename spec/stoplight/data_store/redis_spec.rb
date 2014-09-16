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
      begin
        data_store.sync(name)
        expect(false).to be(true)
      rescue Stoplight::Error::BadDataStore => e
        expect(e.message).to eql(message)
      end
    end

    it 'sets the cause' do
      begin
        data_store.sync(name)
        expect(false).to be(true)
      rescue Stoplight::Error::BadDataStore => e
        expect(e.cause).to eql(error)
      end
    end
  end
end

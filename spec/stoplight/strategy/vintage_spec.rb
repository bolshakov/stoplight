# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'

RSpec.describe Stoplight::Strategy::Vintage do
  describe 'with redis data store' do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }
    let(:redis) { MockRedis.new }

    it_behaves_like Stoplight::Strategy::Vintage
  end

  describe 'with memory data store' do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Strategy::Vintage
  end
end

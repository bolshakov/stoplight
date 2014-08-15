# coding: utf-8

require 'spec_helper'
require 'fakeredis'

describe Stoplight::DataStore::Redis do
  subject(:data_store) { described_class.new(redis) }
  let(:redis) { Redis.new }

  it_behaves_like 'a data store'
end

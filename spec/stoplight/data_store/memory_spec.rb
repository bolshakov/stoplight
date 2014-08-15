# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore::Memory do
  subject(:data_store) { described_class.new }

  it_behaves_like 'a data store'
end

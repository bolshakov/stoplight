# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::DataStore do
  it 'is a module' do
    Stoplight::DataStore.must_be_kind_of(Module)
  end
end

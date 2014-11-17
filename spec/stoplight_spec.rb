# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight do
  it 'is a module' do
    Stoplight.must_be_kind_of(Module)
  end
end

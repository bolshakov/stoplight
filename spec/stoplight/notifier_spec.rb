# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Notifier do
  it 'is a module' do
    Stoplight::Notifier.must_be_kind_of(Module)
  end
end

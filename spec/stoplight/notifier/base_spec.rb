# coding: utf-8

require 'minitest/spec'
require 'stoplight'

describe Stoplight::Notifier::Base do
  it 'is a class' do
    Stoplight::Notifier::Base.must_be_kind_of(Module)
  end

  describe '#notify' do
    it 'is not implemented' do
      -> { Stoplight::Notifier::Base.new.notify(nil, nil, nil, nil) }
        .must_raise(NotImplementedError)
    end
  end
end

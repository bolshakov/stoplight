# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::Base do
  subject(:notifier) { described_class.new }

  %w(
    notify
  ).each do |method|
    it "responds to #{method}" do
      expect(notifier).to respond_to(method)
    end

    it "does not implement #{method}" do
      args = [nil] * notifier.method(method).arity
      expect { notifier.public_send(method, *args) }.to raise_error(
        NotImplementedError)
    end
  end
end

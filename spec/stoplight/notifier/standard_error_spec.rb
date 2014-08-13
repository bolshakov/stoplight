# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::StandardError do
  subject(:notifier) { described_class.new }

  describe '#notify' do
    let(:message) { SecureRandom.hex }

    subject(:result) { notifier.notify(message) }

    it 'emits the message as a warning' do
      expect(notifier).to receive(:warn).with(message)
      result
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::StandardError do
  subject(:notifier) { described_class.new }

  before { @stderr, $stderr = $stderr, StringIO.new }
  after { $stderr = @stderr }

  describe '#notify' do
    let(:message) { SecureRandom.hex }

    subject(:result) { notifier.notify(message) }

    it 'emits the message as a warning' do
      result
      expect($stderr.string).to eql("#{message}\n")
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::StandardError do
  subject(:notifier) { described_class.new(format) }
  let(:format) { nil }

  before { @stderr, $stderr = $stderr, StringIO.new }
  after { $stderr = @stderr }

  describe '#notify' do
    subject(:result) { notifier.notify(message) }
    let(:message) { SecureRandom.hex }

    it 'emits the message as a warning' do
      result
      expect($stderr.string).to eql("#{message}\n")
    end

    context 'with a format' do
      let(:format) { '> %s <' }

      it 'formats the message' do
        result
        expect($stderr.string).to eql("> #{message} <\n")
      end
    end
  end
end

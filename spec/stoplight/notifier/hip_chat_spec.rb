# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::HipChat do
  subject(:notifier) { described_class.new(client, room, format, options) }
  let(:client) { double }
  let(:room) { SecureRandom.hex }
  let(:format) { nil }
  let(:options) { {} }

  describe '#notify' do
    subject(:result) { notifier.notify(message) }
    let(:message) { SecureRandom.hex }

    it 'sends the message to HipChat' do
      expect(client).to receive(:[]).with(room).and_return(client)
      expect(client).to receive(:send)
        .with('Stoplight', "@all #{message}", anything)
      result
    end

    context 'with a format' do
      let(:format) { '> %s <' }

      it 'formats the message' do
        expect(client).to receive(:[]).with(room).and_return(client)
        expect(client).to receive(:send)
          .with('Stoplight', "> #{message} <", anything)
        result
      end
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::HipChat do
  subject(:notifier) { described_class.new(client, room, options) }
  let(:client) { double }
  let(:room) { SecureRandom.hex }
  let(:options) { {} }

  describe '#notify' do
    subject(:result) { notifier.notify(message) }
    let(:message) { SecureRandom.hex }

    it 'sends the message to HipChat' do
      expect(client).to receive(:[]).with(room).and_return(client)
      expect(client).to receive(:send)
      result
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::HipChat do
  subject(:notifier) { described_class.new(client, room, formatter, options) }
  let(:client) { double }
  let(:room) { SecureRandom.hex }
  let(:formatter) { nil }
  let(:options) { {} }

  describe '#notify' do
    subject(:result) { notifier.notify(light, from_color, to_color) }
    let(:light) { Stoplight::Light.new(light_name, &light_code) }
    let(:light_name) { SecureRandom.hex }
    let(:light_code) { -> {} }
    let(:from_color) { Stoplight::DataStore::COLOR_GREEN }
    let(:to_color) { Stoplight::DataStore::COLOR_RED }

    it 'sends the message to HipChat' do
      expect(client).to receive(:[]).with(room).and_return(client)
      expect(client).to receive(:send).with(
        'Stoplight',
        "@all Switching #{light.name} from #{from_color} to #{to_color}",
        anything)
      result
    end

    context 'with a formatter' do
      let(:formatter) { ->(l, f, t) { "#{l.name} #{f} #{t}" } }

      it 'formats the message' do
        expect(client).to receive(:[]).with(room).and_return(client)
        expect(client).to receive(:send).with(
          'Stoplight',
          "#{light.name} #{from_color} #{to_color}",
          anything)
        result
      end
    end
  end
end

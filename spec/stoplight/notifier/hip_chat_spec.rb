# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::HipChat do
  subject(:notifier) { described_class.new(client, room, formatter, options) }
  let(:client) { double }
  let(:room) { SecureRandom.hex }
  let(:formatter) { nil }
  let(:options) { {} }

  describe '#notify' do
    subject(:result) { notifier.notify(light, from_color, to_color, failure) }
    let(:light) { Stoplight::Light.new(light_name, &light_code) }
    let(:light_name) { SecureRandom.hex }
    let(:light_code) { -> {} }
    let(:from_color) { Stoplight::DataStore::COLOR_GREEN }
    let(:to_color) { Stoplight::DataStore::COLOR_RED }
    let(:failure) { nil }
    let(:error) { error_class.new(error_message) }
    let(:error_class) { StandardError }
    let(:error_message) { SecureRandom.hex }

    it 'sends the message to HipChat' do
      expect(client).to receive(:[]).with(room).and_return(client)
      expect(client).to receive(:send).with(
        'Stoplight',
        "@all Switching #{light.name} from #{from_color} to #{to_color}",
        anything)
      result
    end

    context 'with a failure' do
      let(:failure) { Stoplight::Failure.create(error) }

      it 'sends the message to HipChat' do
        expect(client).to receive(:[]).with(room).and_return(client)
        expect(client).to receive(:send).with(
          'Stoplight',
          "@all Switching #{light.name} from #{from_color} to #{to_color} " \
            "because #{error_class} #{error_message}",
          anything)
        result
      end
    end

    context 'with a formatter' do
      let(:formatter) { ->(l, f, t, e) { "#{l.name} #{f} #{t} #{e}" } }

      it 'formats the message' do
        expect(client).to receive(:[]).with(room).and_return(client)
        expect(client).to receive(:send).with(
          'Stoplight',
          "#{light.name} #{from_color} #{to_color} ",
          anything)
        result
      end

      context 'with a failure' do
        let(:failure) { Stoplight::Failure.create(error) }

        it 'formats the message' do
          expect(client).to receive(:[]).with(room).and_return(client)
          expect(client).to receive(:send).with(
            'Stoplight',
            "#{light.name} #{from_color} #{to_color} #{failure}",
            anything)
          result
        end
      end
    end

    context 'failing' do
      let(:error) { HipChat::UnknownResponseCode.new(message) }
      let(:message) { SecureRandom.hex }

      before do
        allow(client).to receive(:[]).with(room).and_return(client)
        allow(client).to receive(:send).and_raise(error)
      end

      it 'reraises the error' do
        expect { result }.to raise_error(Stoplight::Error::BadNotifier)
      end

      it 'sets the message' do
        rescued =
          begin
            result
          rescue Stoplight::Error::BadNotifier => e
            expect(e.message).to eql(message)
            true
          end
        expect(rescued).to eql(true)
      end

      it 'sets the cause' do
        rescued =
          begin
            result
          rescue Stoplight::Error::BadNotifier => e
            expect(e.cause).to eql(error)
            true
          end
        expect(rescued).to eql(true)
      end
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::IO do
  subject(:notifier) { described_class.new(io, formatter) }
  let(:io) { StringIO.new }
  let(:formatter) { nil }

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

    it 'emits the message as a warning' do
      result
      expect(io.string)
        .to eql("Switching #{light.name} from #{from_color} to #{to_color}\n")
    end

    context 'with a failure' do
      let(:failure) { Stoplight::Failure.create(error) }

      it 'emits the message as a warning' do
        result
        expect(io.string).to eql(
          "Switching #{light.name} from #{from_color} to #{to_color} " \
            "because #{error_class} #{error_message}\n")
      end
    end

    context 'with a formatter' do
      let(:formatter) { ->(l, f, t, e) { "#{l.name} #{f} #{t} #{e}" } }

      it 'formats the message' do
        result
        expect(io.string)
          .to eql("#{light.name} #{from_color} #{to_color} \n")
      end

      context 'with a failure' do
        let(:failure) { Stoplight::Failure.create(error) }

        it 'formats the message' do
          result
          expect(io.string)
            .to eql("#{light.name} #{from_color} #{to_color} #{failure}\n")
        end
      end
    end
  end
end

# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::IO do
  subject(:notifier) { described_class.new(io, formatter) }
  let(:io) { StringIO.new }
  let(:formatter) { nil }

  describe '#notify' do
    subject(:result) { notifier.notify(light, from_color, to_color) }
    let(:light) { Stoplight::Light.new(light_name, &light_code) }
    let(:light_name) { SecureRandom.hex }
    let(:light_code) { -> {} }
    let(:from_color) { Stoplight::DataStore::COLOR_GREEN }
    let(:to_color) { Stoplight::DataStore::COLOR_RED }

    it 'emits the message as a warning' do
      result
      expect(io.string)
        .to eql("Switching #{light.name} from #{from_color} to #{to_color}\n")
    end

    context 'with a formatter' do
      let(:formatter) { ->(l, f, t) { "#{l.name} #{f} #{t}" } }

      it 'formats the message' do
        result
        expect(io.string)
          .to eql("#{light.name} #{from_color} #{to_color}\n")
      end
    end
  end
end

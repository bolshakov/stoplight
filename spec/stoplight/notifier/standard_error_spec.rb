# coding: utf-8

require 'spec_helper'

describe Stoplight::Notifier::StandardError do
  subject(:notifier) { described_class.new(format) }
  let(:format) { nil }

  before { @stderr, $stderr = $stderr, StringIO.new }
  after { $stderr = @stderr }

  describe '#notify' do
    subject(:result) { notifier.notify(light, from_color, to_color) }
    let(:light) { Stoplight::Light.new(light_name, &light_code) }
    let(:light_name) { SecureRandom.hex }
    let(:light_code) { -> {} }
    let(:from_color) { Stoplight::DataStore::COLOR_GREEN }
    let(:to_color) { Stoplight::DataStore::COLOR_RED }

    it 'emits the message as a warning' do
      result
      expect($stderr.string)
        .to eql("Switching #{light.name} from #{from_color} to #{to_color}\n")
    end

    context 'with a format' do
      let(:format) { '%s %s %s' }

      it 'formats the message' do
        result
        expect($stderr.string)
          .to eql("#{light.name} #{from_color} #{to_color}\n")
      end
    end
  end
end

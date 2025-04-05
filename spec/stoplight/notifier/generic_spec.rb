# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Notifier::Generic do
  let(:light) { Stoplight(name).build }
  let(:name) { ('a'..'z').to_a.shuffle.join }
  let(:from_color) { Stoplight::Color::GREEN }
  let(:to_color) { Stoplight::Color::RED }
  let(:error) { nil }

  it 'is a module' do
    expect(described_class).to be_a(Module)
  end

  describe '#put' do
    let(:notifier) { notifier_class.new(double.as_null_object) }
    let(:notifier_class) do
      Class.new do
        include Stoplight::Notifier::Generic
      end
    end

    it 'has to implement the #put method' do
      expect do
        notifier.notify(light, from_color, to_color, error)
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#notify' do
    let(:formatted_message) { 'formatted message' }
    let(:notifier) { notifier_class.new(object) }
    let(:notifier_class) do
      Class.new do
        include Stoplight::Notifier::Generic
        def put(message)
          object.put(message)
        end
      end

      it 'puts formatted message' do
        expect(formatter).to receive(:call).with(light, from_color, to_color, error) { formatted_message }
        expect(object).to receive(:put).with(formatted_message)

        expect(notifier.notify(light, from_color, to_color, error)).to eq(formatted_message)
      end
    end
  end
end

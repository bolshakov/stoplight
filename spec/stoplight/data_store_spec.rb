# coding: utf-8

require 'spec_helper'

describe Stoplight::DataStore do
  describe '.validate_color!' do
    subject(:result) { described_class.validate_color!(color) }
    let(:color) { nil }

    context 'with an invalid color' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidColor)
      end
    end
  end

  describe '.validate_failure!' do
    subject(:result) { described_class.validate_failure!(failure) }
    let(:failure) { nil }

    context 'with an invalid failure' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidFailure)
      end
    end
  end

  describe '.validate_state!' do
    subject(:result) { described_class.validate_state!(state) }
    let(:state) { nil }

    context 'with an invalid state' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidState)
      end
    end
  end

  describe '.validate_threshold!' do
    subject(:result) { described_class.validate_threshold!(threshold) }
    let(:threshold) { nil }

    context 'with an invalid threshold' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidThreshold)
      end
    end

    context 'with a negative threshold' do
      let(:threshold) { -1 }

      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidThreshold)
      end
    end

    context 'with a zero threshold' do
      let(:threshold) { 0 }

      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidThreshold)
      end
    end
  end

  describe '.validate_timeout!' do
    subject(:result) { described_class.validate_timeout!(timeout) }
    let(:timeout) { nil }

    context 'with an invalid timeout' do
      it 'raises an error' do
        expect { result }.to raise_error(Stoplight::Error::InvalidTimeout)
      end
    end
  end
end

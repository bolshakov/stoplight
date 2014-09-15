# coding: utf-8
# rubocop:disable Metrics/LineLength

require 'spec_helper'

describe Stoplight::Light do
  before do
    @notifiers = Stoplight.notifiers
    Stoplight.notifiers = []
  end
  after { Stoplight.notifiers = @notifiers }

  subject(:light) { described_class.new(name, &code) }
  let(:allowed_errors) { [error_class] }
  let(:code_result) { double }
  let(:code) { -> { code_result } }
  let(:error_class) { Class.new(StandardError) }
  let(:error) { error_class.new(message) }
  let(:fallback_result) { double }
  let(:fallback) { -> { fallback_result } }
  let(:message) { SecureRandom.hex }
  let(:name) { SecureRandom.hex }
  let(:threshold) { rand(100) }
  let(:timeout) { rand(100) }

  it { expect(light.run).to eql(code_result) }
  it { expect(light.with_allowed_errors(allowed_errors)).to equal(light) }
  it { expect(light.with_fallback(&fallback)).to equal(light) }
  it { expect(light.with_threshold(threshold)).to equal(light) }
  it { expect(light.with_timeout(timeout)).to equal(light) }
  it { expect { light.fallback }.to raise_error(Stoplight::Error::RedLight) }
  it { expect(light.allowed_errors).to eql([]) }
  it { expect(light.code).to eql(code) }
  it { expect(light.name).to eql(name) }
  it { expect(light.color).to eql(Stoplight::DataStore::COLOR_GREEN) }
  it { expect(light.green?).to eql(true) }
  it { expect(light.yellow?).to eql(false) }
  it { expect(light.red?).to eql(false) }
  it { expect(light.threshold).to eql(Stoplight::DataStore::DEFAULT_THRESHOLD) }
  it { expect(light.timeout).to eql(Stoplight::DataStore::DEFAULT_TIMEOUT) }

  it 'sets the allowed errors' do
    light.with_allowed_errors(allowed_errors)
    expect(light.allowed_errors).to eql(allowed_errors)
  end

  it 'sets the fallback' do
    light.with_fallback(&fallback)
    expect(light.fallback).to eql(fallback)
  end

  it 'sets the threshold' do
    light.with_threshold(threshold)
    expect(light.threshold).to eql(threshold)
  end

  it 'sets the timeout' do
    light.with_timeout(timeout)
    expect(light.timeout).to eql(timeout)
  end

  context 'failing' do
    let(:code_result) { fail error }

    it 'switches to red' do
      light.threshold.times do
        expect(light.green?).to eql(true)
        expect { light.run }.to raise_error(error_class)
      end
      expect(light.red?).to eql(true)
      expect { light.run }.to raise_error(Stoplight::Error::RedLight)
    end

    context 'with allowed errors' do
      before { light.with_allowed_errors(allowed_errors) }

      it 'stays green' do
        light.threshold.times do
          expect(light.green?).to eql(true)
          expect { light.run }.to raise_error(error_class)
        end
        expect(light.green?).to eql(true)
        expect { light.run }.to raise_error(error_class)
      end
    end

    context 'with fallback' do
      before { light.with_fallback(&fallback) }

      it 'calls the fallback' do
        light.threshold.times do
          expect(light.green?).to eql(true)
          expect { light.run }.to raise_error(error_class)
        end
        expect(light.red?).to eql(true)
        expect(light.run).to eql(fallback_result)
      end
    end

    context 'with timeout' do
      before { light.with_timeout(-1) }

      it 'switch to yellow' do
        light.threshold.times do
          expect(light.green?).to eql(true)
          expect { light.run }.to raise_error(error_class)
        end
        expect(light.yellow?).to eql(true)
        expect { light.run }.to raise_error(error_class)
      end
    end
  end
end

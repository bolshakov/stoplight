# coding: utf-8
# rubocop:disable Metrics/LineLength

require 'spec_helper'

describe Stoplight::Light do
  subject(:light) { described_class.new(name, &code) }
  let(:name) { SecureRandom.hex }
  let(:code) { -> { code_result } }
  let(:code_result) { double }
  let(:allowed_errors) { [error_class] }
  let(:error_class) { Class.new(StandardError) }
  let(:fallback) { -> { fallback_result } }
  let(:fallback_result) { double }
  let(:threshold) { rand(100) }
  let(:timeout) { rand(100) }

  it { expect(light.run).to eql(code_result) }
  it { expect(light.with_allowed_errors(allowed_errors)).to eql(light) }
  it { expect(light.with_fallback(&fallback)).to eql(light) }
  it { expect(light.with_threshold(threshold)).to eql(light) }
  it { expect(light.with_timeout(timeout)).to eql(light) }
  it { expect { light.fallback }.to raise_error(Stoplight::Error::RedLight) }
  it { expect(light.allowed_errors).to eql([]) }
  it { expect(light.code).to eql(code) }
  it { expect(light.name).to eql(name) }
  it { expect(light.green?).to eql(true) }
  it { expect(light.yellow?).to eql(false) }
  it { expect(light.red?).to eql(false) }
  it { expect(light.threshold).to eql(Stoplight::DataStore::DEFAULT_THRESHOLD) }
  it { expect(light.timeout).to eql(Stoplight::DataStore::DEFAULT_TIMEOUT) }
end

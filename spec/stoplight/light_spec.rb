# coding: utf-8

require 'spec_helper'

describe Stoplight::Light do
  let(:code) { proc { code_result } }
  let(:code_result) { double }
  let(:name) { SecureRandom.hex }

  subject(:light) { described_class.new(name, &code) }

  describe '#initialize' do
    it 'uses the default allowed errors' do
      expect(light.allowed_errors).to eql([])
    end

    it 'sets the code' do
      expect(light.code).to eql(code.to_proc)
    end

    it 'sets the name' do
      expect(light.name).to eql(name.to_s)
    end
  end

  describe '#run' do
    subject(:result) { light.with_fallback(&fallback).run }
    let(:fallback) { proc { fallback_result } }
    let(:fallback_result) { double }

    it 'sync settings' do
      expect(Stoplight.data_store.threshold(name)).to be(nil)
      result
      expect(Stoplight.data_store.threshold(name)).to eql(light.threshold)
    end

    shared_examples 'run_code' do
      it 'runs the code' do
        expect(result).to eql(code_result)
      end

      it 'clears failures' do
        Stoplight.record_failure(name, nil)
        result
        expect(Stoplight.failures(name)).to be_empty
      end

      context 'with failing code' do
        let(:code_result) { fail error }
        let(:error) { error_class.new }
        let(:error_class) { Class.new(StandardError) }
        let(:safe_result) do
          begin
            result
          rescue error_class
            nil
          end
        end

        it 'raises the error' do
          expect { result }.to raise_error(error)
        end

        it 'records the failure' do
          failures = Stoplight.failures(name)
          safe_result
          expect(Stoplight.failures(name).size).to eql(failures.size + 1)
        end

        context 'with the error allowed' do
          let(:allowed_errors) { [error_class] }

          before { light.with_allowed_errors(allowed_errors) }

          it 'raises the error' do
            expect { result }.to raise_error(error)
          end

          it 'clears failures' do
            Stoplight.record_failure(name, nil)
            safe_result
            expect(Stoplight.failures(name)).to be_empty
          end
        end
      end
    end

    context 'green' do
      before do
        allow(light).to receive(:green?).and_return(true)
        allow(light).to receive(:yellow?).and_return(false)
        allow(light).to receive(:red?).and_return(false)
      end

      include_examples 'run_code'
    end

    context 'yellow' do
      before do
        allow(light).to receive(:green?).and_return(false)
        allow(light).to receive(:yellow?).and_return(true)
        allow(light).to receive(:red?).and_return(false)
      end

      include_examples 'run_code'
    end

    context 'red' do
      before do
        allow(light).to receive(:green?).and_return(false)
        allow(light).to receive(:yellow?).and_return(false)
        allow(light).to receive(:red?).and_return(true)
      end

      it 'runs the fallback' do
        expect(result).to eql(fallback_result)
      end

      it 'records the attempt' do
        result
        expect(Stoplight.attempts(name)).to eql(1)
      end
    end
  end

  describe '#with_allowed_errors' do
    let(:allowed_errors) { [double] }

    subject(:result) { light.with_allowed_errors(allowed_errors) }

    it 'returns self' do
      expect(result).to be light
    end

    it 'sets the allowed errors' do
      expect(result.allowed_errors).to eql(allowed_errors)
    end
  end

  describe '#with_fallback' do
    let(:fallback) { proc { fallback_result } }
    let(:fallback_result) { double }

    subject(:result) { light.with_fallback(&fallback) }

    it 'returns self' do
      expect(result).to be light
    end

    it 'sets the fallback' do
      expect(result.fallback).to eql(fallback)
    end
  end

  describe '#with_threshold' do
    let(:threshold) { rand(10) }

    subject(:result) { light.with_threshold(threshold) }

    it 'returns self' do
      expect(result).to be light
    end

    it 'sets the threshold' do
      expect(result.threshold).to eql(threshold)
    end
  end

  describe '#fallback' do
    subject(:result) { light.fallback }

    it 'uses the default fallback' do
      expect { result }.to raise_error(Stoplight::Error::RedLight)
    end
  end

  describe '#green?' do
    subject(:result) { light.green? }

    it 'is true' do
      expect(result).to be true
    end

    context 'locked green' do
      before do
        Stoplight.set_state(name, Stoplight::DataStore::STATE_LOCKED_GREEN)
      end

      it 'is true' do
        expect(result).to be true
      end
    end

    context 'locked red' do
      before do
        Stoplight.set_state(name, Stoplight::DataStore::STATE_LOCKED_RED)
      end

      it 'is false' do
        expect(result).to be false
      end
    end

    context 'with failures' do
      before do
        light.threshold.times { Stoplight.record_failure(name, nil) }
      end

      it 'is false' do
        expect(result).to be false
      end
    end
  end

  describe '#red?' do
    subject(:result) { light.red? }

    context 'green' do
      before { allow(light).to receive(:green?).and_return(true) }

      it 'is false' do
        expect(result).to be false
      end
    end

    context 'not green' do
      before do
        allow(Stoplight).to receive(:green?).with(name).and_return(false)
      end

      it 'is true' do
        expect(result).to be true
      end
    end
  end

  describe '#threshold' do
    subject(:result) { light.threshold }

    it 'uses the default threshold' do
      expect(result).to eql(Stoplight::DEFAULT_THRESHOLD)
    end
  end
end

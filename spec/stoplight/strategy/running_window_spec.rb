# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'

RSpec.describe Stoplight::Strategy::RunningWindow do
  subject(:strategy) { described_class.new(data_store, window: window) }

  let(:window) { 3600 }

  shared_examples Stoplight::Strategy::RunningWindow do
    let(:light) { Stoplight::Light.new(name) {} }
    let(:name) { SecureRandom.uuid }

    describe '#get_all' do
      context 'when there is no failures' do
        it 'returns no failures and state' do
          failures, state = strategy.get_all(light)
          expect(failures).to eql([])
          expect(state).to eql(Stoplight::State::UNLOCKED)
        end
      end

      context 'when there are failures' do
        let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

        before do
          strategy.record_failure(light, failure)
        end

        it 'returns failures and state' do
          failures, state = strategy.get_all(light)
          expect(failures).to contain_exactly(failure)
          expect(state).to eql(Stoplight::State::UNLOCKED)
        end
      end
    end

    describe '#get_failures' do
      subject { strategy.get_failures(light) }

      context 'when there is no failures' do
        it { is_expected.to be_empty }
      end

      context 'when there are failures' do
        let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

        before do
          strategy.record_failure(light, failure)
        end

        it { is_expected.to contain_exactly(failure) }
      end
    end

    describe '#record_failure' do
      let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

      it 'returns the number of failures' do
        expect(strategy.record_failure(light, failure)).to eql(1)
      end

      context 'when there are many failures' do
        def failures
          strategy.get_failures(light)
        end

        let(:another_failure) { Stoplight::Failure.new('class', 'message 2', Time.new - 10) }

        it 'stores more recent failures at the head' do
          strategy.record_failure(light, failure)
          strategy.record_failure(light, another_failure)

          expect(failures).to eq([another_failure, failure])
        end

        describe 'threshold' do
          let(:one_another_failure) { Stoplight::Failure.new('class', 'message 2', Time.new - 20) }

          it 'limits the number of stored failures' do
            light.with_threshold(1)
            strategy.record_failure(light, one_another_failure)
            strategy.record_failure(light, another_failure)
            expect(failures).to contain_exactly(another_failure)

            strategy.record_failure(light, failure)

            expect(failures).to contain_exactly(failure)
          end
        end

        describe 'running window' do
          let(:another_failure) { Stoplight::Failure.new('class', 'message 2', Time.new - window - 1) }

          it 'stores failures only withing window length' do
            strategy.record_failure(light, failure)
            strategy.record_failure(light, another_failure)

            expect(failures).to contain_exactly(failure)
          end
        end
      end
    end

    describe '#clear_failures' do
      let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }
      let(:another_failure) { Stoplight::Failure.new('class', 'message 2', Time.new - window - 1) }

      before do
        strategy.record_failure(light, failure)
        strategy.record_failure(light, another_failure)
      end

      it 'returns the failures from the window' do
        expect(strategy.clear_failures(light)).to eq([failure])
      end

      it 'clears failures' do
        strategy.clear_failures(light)
        expect(strategy.get_failures(light)).to eql([])
      end
    end
  end

  describe 'with redis data store' do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }
    let(:redis) { MockRedis.new }

    it_behaves_like Stoplight::Strategy::RunningWindow
  end

  describe 'with memory data store' do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Strategy::RunningWindow
  end
end

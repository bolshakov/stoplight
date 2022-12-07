# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#record_failures' do
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { SecureRandom.uuid }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }
  let(:other_failure) { Stoplight::Failure.new('class', 'message 2', Time.new - 10) }

  shared_examples '#record_failure' do
    it 'returns the number of failures' do
      expect(data_store.record_failure(light, failure, window: window)).to eql(1)
    end

    it 'persists the failure' do
      data_store.record_failure(light, failure)

      expect(data_store.get_failures(light)).to contain_exactly(failure)
    end

    context 'when there are multiple failures' do
      it 'stores more recent failures at the head' do
        data_store.record_failure(light, failure, window: window)
        data_store.record_failure(light, other_failure, window: window)

        expect(data_store.get_failures(light, window: window)).to eq([failure, other_failure])
      end

      it 'limits the number of stored failures' do
        light.with_threshold(1)

        data_store.record_failure(light, failure, window: window)
        data_store.record_failure(light, other_failure, window: window)

        expect(data_store.get_failures(light, window: window)).to contain_exactly(failure)
      end
    end
  end

  context 'without a window' do
    let(:window) { nil }

    include_examples '#record_failure'
  end

  context 'with a window' do
    let(:window) { 3600 }

    include_examples '#record_failure'

    context 'when error is outside of the window' do
      let(:old_failure) { Stoplight::Failure.new('class', 'message 3', Time.new - window - 1) }

      it 'stores failures only withing window length' do
        data_store.record_failure(light, failure, window: window)
        data_store.record_failure(light, other_failure, window: window)
        data_store.record_failure(light, old_failure, window: window)

        expect(data_store.get_failures(light, window: window)).to eq([failure, other_failure])
      end
    end
  end
end

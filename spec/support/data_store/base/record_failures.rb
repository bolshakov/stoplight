# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#record_failure' do
  shared_examples '#record_failure' do
    it 'returns the number of failures' do
      expect(data_store.record_failure(light, failure, window: window)).to eql(1)
    end

    context 'when there is an error' do
      before do
        data_store.record_failure(light, failure, window: window)
      end

      it 'persists the failure' do
        expect(data_store.get_failures(light, window: window)).to eq([failure])
      end
    end

    context 'when there is are several errors' do
      before do
        data_store.record_failure(light, failure, window: window)
        data_store.record_failure(light, other, window: window)
      end

      it 'stores more recent failures at the head' do
        expect(data_store.get_failures(light, window: window)).to eq([other, failure])
      end
    end

    context 'when the number of errors is bigger then threshold' do
      before do
        light.with_threshold(1)

        data_store.record_failure(light, failure, window: window)
      end

      it 'limits the number of stored failures' do
        expect do
          data_store.record_failure(light, other, window: window)
        end.to change { data_store.get_failures(light, window: window) }
          .from([failure])
          .to([other])
      end
    end
  end

  context 'without window' do
    let(:window) { nil }

    it_behaves_like '#record_failure'
  end
end

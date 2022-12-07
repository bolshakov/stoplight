# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#clear_failures' do
  shared_examples '#clear_failures' do
    before do
      data_store.record_failure(light, failure, window: window)
    end

    it 'returns the failures' do
      expect(data_store.clear_failures(light, window: window)).to contain_exactly(failure)
    end

    it 'clears the failures' do
      expect do
        data_store.clear_failures(light, window: window)
      end.to change { data_store.get_failures(light, window: window) }
        .from([failure]).to(be_empty)
    end
  end

  context 'without window' do
    let(:window) { nil }

    it_behaves_like '#clear_failures'
  end
end

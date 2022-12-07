# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_failures' do
  shared_examples '#get_failures' do
    it 'is initially empty' do
      expect(data_store.get_failures(light, window: window)).to eql([])
    end

    it 'returns failures' do
      expect { data_store.record_failure(light, failure, window: window) }
        .to change { data_store.get_failures(light, window: window) }
        .from(be_empty)
        .to(contain_exactly(failure))
    end
  end

  context 'without window' do
    let(:window) { nil }

    it_behaves_like '#get_failures'
  end
end

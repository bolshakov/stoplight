# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_all' do
  context 'when there are no errors' do
    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)

      expect(failures).to eql([])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end

  context 'when there are errors' do
    before do
      data_store.record_failure(light, failure)
    end

    it 'returns the failures and the state' do
      failures, state = data_store.get_all(light)

      expect(failures).to eq([failure])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end
end

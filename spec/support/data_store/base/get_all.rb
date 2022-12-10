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

  context 'when there is a failure outside of the window' do
    let(:window_size) { 3600 }
    let(:older_failure) { Stoplight::Failure.new('class', 'message 3', Time.new - window_size - 1) }

    before do
      light.with_window_size(window_size)

      data_store.record_failure(light, older_failure)
      data_store.record_failure(light, failure)
    end

    it 'returns the failures within window and the state' do
      failures, state = data_store.get_all(light)

      expect(failures).to contain_exactly(failure)
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end
end

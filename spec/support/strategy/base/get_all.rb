# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Strategy::Base#get_all' do
  context 'when there are no failures' do
    it 'returns the failures and the state' do
      failures, state = strategy.get_all(light)

      expect(failures).to eql([])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end

  context 'when there are failures' do
    before do
      strategy.record_failure(light, failure)
    end

    it 'returns the failures and the state' do
      failures, state = strategy.get_all(light)

      expect(failures).to eq([failure])
      expect(state).to eql(Stoplight::State::UNLOCKED)
    end
  end
end

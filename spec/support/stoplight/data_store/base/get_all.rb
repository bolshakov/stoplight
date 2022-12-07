# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_all' do
  subject(:get_all) { data_store.get_all(light, window: window) }

  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { SecureRandom.uuid }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  shared_examples '#get_all' do
    context 'when there are no failures' do
      it 'returns no failures and the state' do
        failures, state = get_all

        expect(failures).to eql([])
        expect(state).to eql(Stoplight::State::UNLOCKED)
      end
    end

    context 'when there are failures' do
      before do
        data_store.record_failure(light, failure)
      end

      it 'returns the failures and the state' do
        failures, state = get_all

        expect(failures).to contain_exactly(failure)
        expect(state).to eql(Stoplight::State::UNLOCKED)
      end
    end
  end

  context 'without window' do
    let(:window) { nil }

    it_behaves_like '#get_all'
  end

  context 'with window' do
    let(:window) { 3600 }

    it_behaves_like '#get_all'

    context 'when there are failures outside of the window' do
      let(:older_failure) do
        Stoplight::Failure.new('class', 'older failure', Time.new - window - 1)
      end

      before do
        data_store.record_failure(light, older_failure)
        data_store.record_failure(light, failure)
      end

      it 'returns the failures within window and the state' do
        failures, state = get_all

        expect(failures).to contain_exactly(failure)
        expect(state).to eql(Stoplight::State::UNLOCKED)
      end
    end
  end
end

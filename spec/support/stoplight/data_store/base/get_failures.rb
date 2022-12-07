# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_failures' do
  let(:light) { Stoplight::Light.new(name) {} }
  let(:name) { SecureRandom.uuid }
  let(:failure) { Stoplight::Failure.new('class', 'message', Time.new) }

  shared_examples '#get_failures' do
    it 'is initially empty' do
      expect(data_store.get_failures(light, window: window)).to eql([])
    end
  end

  context 'without window' do
    let(:window) { nil }

    include_examples '#get_failures'

    it 'returns failures' do
      data_store.record_failure(light, failure)

      expect(data_store.get_failures(light)).to contain_exactly(failure)
    end
  end

  context 'with window' do
    let(:window) { 3600 }
    let(:older_failure) { Stoplight::Failure.new('class', 'old failure', Time.new - window - 1) }

    include_examples '#get_failures'

    it 'returns failures withing given window' do
      data_store.record_failure(light, failure, window: window)
      data_store.record_failure(light, older_failure, window: window)

      expect(data_store.get_failures(light, window: window)).to contain_exactly(failure)
    end
  end
end

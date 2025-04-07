# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_failures' do
  it 'is initially empty' do
    expect(data_store.get_failures(config)).to eql([])
  end

  it 'handles invalid JSON' do
    expect { data_store.record_failure(config, failure) }
      .to change { data_store.get_failures(config) }
      .from(be_empty)
      .to(contain_exactly(failure))
  end

  context 'when there is a failure outside of the window' do
    let(:window_size) { 3600 }
    let(:older_failure) { Stoplight::Failure.new('class', 'message 3', Time.new - window_size - 1) }
    let(:config) { super().with(window_size: window_size) }

    before do
      data_store.record_failure(config, failure)
      data_store.record_failure(config, older_failure)
    end

    it 'returns failures withing given window' do
      expect(data_store.get_failures(config)).to contain_exactly(failure)
    end
  end
end

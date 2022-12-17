# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::DataStore::Base#get_failures' do
  it 'is initially empty' do
    expect(data_store.get_failures(light)).to eql([])
  end

  it 'handles invalid JSON' do
    expect { data_store.record_failure(light, failure) }
      .to change { data_store.get_failures(light) }
      .from(be_empty)
      .to(contain_exactly(failure))
  end

  context 'when there is a failure outside of the window' do
    let(:window_size) { 3600 }
    let(:older_failure) { Stoplight::Failure.new('class', 'message 3', Time.new - window_size - 1) }

    before do
      light.with_window_size(window_size)

      data_store.record_failure(light, failure)
      data_store.record_failure(light, older_failure)
    end

    it 'returns failures withing given window' do
      expect(data_store.get_failures(light)).to contain_exactly(failure)
    end
  end
end

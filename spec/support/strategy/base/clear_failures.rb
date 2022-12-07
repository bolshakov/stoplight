# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Strategy::Base#clear_failures' do
  before do
    strategy.record_failure(light, failure)
  end

  it 'returns the failures' do
    expect(strategy.clear_failures(light)).to contain_exactly(failure)
  end

  it 'clears the failures' do
    expect do
      strategy.clear_failures(light)
    end.to change { strategy.get_failures(light) }
      .from([failure]).to(be_empty)
  end
end

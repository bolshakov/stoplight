# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Strategy::Base#get_failures' do
  it 'is initially empty' do
    expect(strategy.get_failures(light)).to eql([])
  end

  it 'returns failures' do
    expect { strategy.record_failure(light, failure) }
      .to change { strategy.get_failures(light) }
      .from(be_empty)
      .to(contain_exactly(failure))
  end
end

# frozen_string_literal: true

RSpec.shared_examples 'Stoplight::Strategy::Base#record_failure' do
  def failures
    strategy.get_failures(light)
  end

  it 'returns the number of failures' do
    expect(strategy.record_failure(light, failure)).to eql(1)
  end

  context 'when there is an error' do
    before do
      strategy.record_failure(light, failure)
    end

    it 'persists the failure' do
      expect(failures).to eq([failure])
    end
  end

  context 'when there is are several errors' do
    before do
      strategy.record_failure(light, failure)
      strategy.record_failure(light, other)
    end

    it 'stores more recent failures at the head' do
      expect(failures).to eq([other, failure])
    end
  end

  context 'when the number of errors is bigger then threshold' do
    before do
      light.with_threshold(1)

      strategy.record_failure(light, failure)
    end

    it 'limits the number of stored failures' do
      expect do
        strategy.record_failure(light, other)
      end.to change { failures }
        .from([failure])
        .to([other])
    end
  end
end

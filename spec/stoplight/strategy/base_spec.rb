# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoplight::Strategy::Base do
  it_behaves_like Stoplight::Strategy::Base do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    describe '#get_all' do
      it 'is not implemented' do
        expect { strategy.get_all(nil) }.to raise_error(NotImplementedError)
      end
    end

    describe '#get_failures' do
      it 'is not implemented' do
        expect { strategy.get_failures(nil) }
          .to raise_error(NotImplementedError)
      end
    end

    describe '#record_failure' do
      it 'is not implemented' do
        expect { strategy.record_failure(nil, nil) }
          .to raise_error(NotImplementedError)
      end
    end

    describe '#clear_failures' do
      it 'is not implemented' do
        expect { strategy.clear_failures(nil) }
          .to raise_error(NotImplementedError)
      end
    end
  end
end

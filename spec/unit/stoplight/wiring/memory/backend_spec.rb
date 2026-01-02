# frozen_string_literal: true

require_relative "../data_store_backend"

RSpec.describe Stoplight::Wiring::Memory::Backend do
  it_behaves_like Stoplight::Wiring::DataStoreBackend do
    let(:backend) { described_class.new(clock:, config:) }
  end
end

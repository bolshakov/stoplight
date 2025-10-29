# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Strategies::RunStrategy do
  describe "#execute" do
    subject(:strategy) { described_class.new(config:, data_store:) }

    let(:config) { instance_double(Stoplight::Domain::Config) }
    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
    let(:metadata) { instance_double(Stoplight::Domain::Metadata) }

    it "raises NotImplementedError" do
      expect { strategy.execute(nil, metadata:) {} }.to raise_error(NotImplementedError)
    end
  end
end

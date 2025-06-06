# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::RunStrategy do
  describe "#execute" do
    subject(:strategy) { described_class.new(config) }

    let(:config) { instance_double(Stoplight::Light::Config, data_store:) }
    let(:data_store) { instance_double(Stoplight::DataStore::Base) }

    it "raises NotImplementedError" do
      expect { strategy.execute(nil) {} }.to raise_error(NotImplementedError)
    end
  end
end

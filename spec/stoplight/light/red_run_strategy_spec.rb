# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::RedRunStrategy do
  subject(:strategy) { described_class.new(config) }

  let(:config) { Stoplight.default_config.with(name: "foo", data_store:) }

  shared_examples Stoplight::Light::RedRunStrategy do
    subject(:result) { strategy.execute(fallback) { 42 } }

    context "when fallback is provided" do
      let(:fallback) {
        ->(error) {
          @error = error
          "Fallback"
        }
      }

      it "returns fallback" do
        expect(result).to eq("Fallback")

        expect(@error).to eq(nil)
      end
    end

    context "when fallback is not provided" do
      let(:fallback) { nil }

      it "records and raises the error" do
        expect { result }.to raise_error(Stoplight::Error::RedLight, config.name)
      end
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like Stoplight::Light::RedRunStrategy
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like Stoplight::Light::RedRunStrategy
  end
end

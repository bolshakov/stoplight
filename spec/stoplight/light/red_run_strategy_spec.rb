# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::RedRunStrategy, :freeze do
  subject(:strategy) { described_class.new(config:, data_store:) }

  let(:config) do
    Stoplight::Domain::Config.empty.with(name: "foo")
  end
  let(:metadata) { instance_double(Stoplight::Metadata, recovery_scheduled_after: Time.now) }

  shared_examples Stoplight::Light::RedRunStrategy do
    subject(:result) { strategy.execute(fallback, metadata:) { 42 } }

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
        expect { result }.to raise_error(Stoplight::Error::RedLight, config.name) { |error|
          expect(error.cool_off_time).to eq(config.cool_off_time)
          expect(error.retry_after).to eq(metadata.recovery_scheduled_after)
        }
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

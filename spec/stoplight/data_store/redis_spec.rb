# frozen_string_literal: true

require "connection_pool"
require "spec_helper"

RSpec.describe Stoplight::DataStore::Redis, :redis do
  let(:config) { Stoplight.config_provider.provide(name, window_size:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new("class", "message", Time.new - 60) }
  let(:other) { Stoplight::Failure.new("class", "message 2", Time.new) }
  let(:window_size) { Stoplight::Default::WINDOW_SIZE }

  describe ".buckets_for_window" do
    subject(:buckets) { described_class.buckets_for_window(light_name, metric:, window_end:, window_size:) }

    let(:light_name) { "test-light" }
    let(:metric) { "failures" }

    context "when window size is smaller than the bucket size" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 34, 56) }
      let(:window_size) { 1000 } # Smaller than BUCKET_SIZE (3600)

      it "returns a single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:metrics:test-light:failures:1696154400"
        )
      end
    end

    context "when window size spans multiple buckets" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 0, 0) }
      let(:window_size) { 14400 } # Spans 4 buckets (3600s each)

      it "returns all bucket keys within the window" do
        is_expected.to contain_exactly(
          "stoplight:v5:metrics:test-light:failures:1696140000",
          "stoplight:v5:metrics:test-light:failures:1696143600",
          "stoplight:v5:metrics:test-light:failures:1696147200",
          "stoplight:v5:metrics:test-light:failures:1696150800"
        )
      end
    end

    context "when window size is exactly one bucket size" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 0, 0) }
      let(:window_size) { 3600 } # Exactly one bucket size

      it "returns the single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:metrics:test-light:failures:1696150800"
        )
      end
    end

    context "when window size is exactly one bucket size" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 30, 0) }
      let(:window_size) { nil }

      it "returns at most 144 buckets (1 day)" do
        is_expected.to have_attributes(count: 25)
      end
    end
  end

  shared_examples Stoplight::DataStore::Redis do
    it_behaves_like "data store metrics" do
      context "when JSON is invalid" do
        let(:config) { Stoplight.config_provider.provide(name, error_notifier: ->(_error) {}) }

        it "handles it without an error" do
          expect(failure).to receive(:to_json).and_return("invalid JSON")

          expect { data_store.record_failure(config, failure) }
            .to change { data_store.get_metadata(config) }
            .to(
              have_attributes(
                last_failure: have_attributes(
                  error_class: "JSON::ParserError"
                )
              )
            )
        end
      end
    end

    it_behaves_like "Stoplight::DataStore::Base"
    it_behaves_like "Stoplight::DataStore::Base#names"
    it_behaves_like "Stoplight::DataStore::Base#get_state"
    it_behaves_like "Stoplight::DataStore::Base#set_state"
    it_behaves_like "Stoplight::DataStore::Base#clear_state"
    it_behaves_like "Stoplight::DataStore::Base#transition_to_color"
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(redis) }
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(pool) }
    let(:pool) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end

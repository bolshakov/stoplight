# frozen_string_literal: true

require "connection_pool"
require "spec_helper"

RSpec.describe Stoplight::DataStore::Redis, :redis do
  let(:config) { Stoplight.config_provider.provide(name) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new("class", "message", Time.new - 60) }
  let(:other) { Stoplight::Failure.new("class", "message 2", Time.new) }


  describe ".buckets_key_for_time" do
    subject(:buckets_key_for_time) { described_class.buckets_key_for_time(light_name, time) }

    let(:light_name) { "test-light" }

    context "when time is a Time object" do
      let(:time) { Time.new(2023, 10, 1, 12, 34, 56) }

      it "returns keys for all bucket sizes for the given time" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:1s:1696156496",
          "stoplight:v5:stats:test-light:10s:1696156490",
          "stoplight:v5:stats:test-light:60s:1696156440"
        )
      end
    end

    context "when time is a numeric timestamp" do
      let(:time) { 1696156496 }

      it "handles numeric time input correctly" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:1s:1696156496",
          "stoplight:v5:stats:test-light:10s:1696156490",
          "stoplight:v5:stats:test-light:60s:1696156440"
        )
      end
    end

    context "when time is exactly on a bucket boundary" do
      let(:time) { Time.new(2023, 10, 1, 12, 34, 0) }

      it "returns keys aligned to bucket boundaries" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:1s:1696156440",
          "stoplight:v5:stats:test-light:10s:1696156440",
          "stoplight:v5:stats:test-light:60s:1696156440"
        )
      end
    end
  end

  describe ".buckets_for_window" do
    subject(:buckets_for_window) { described_class.buckets_for_window("test-light", window_end:, window_size:) }

    let(:window_end) { Time.new(2023, 10, 1, 12, 34, 56) }

    context "when window size is less than 10 seconds" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 34, 56) }
      let(:window_size) { 5 }

      it "returns only 1-second buckets" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:1s:1696156496",
          "stoplight:v5:stats:test-light:1s:1696156495",
          "stoplight:v5:stats:test-light:1s:1696156494",
          "stoplight:v5:stats:test-light:1s:1696156493",
          "stoplight:v5:stats:test-light:1s:1696156492"
        )
      end
    end


    context "when window size is between 10 and 60 seconds" do
      let(:window_end) { Time.new(2023, 10, 1, 12, 34, 56) }
      let(:window_size) { 25 }

      it "returns a mix of 10-second and 1-second buckets" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:10s:1696156490",
          "stoplight:v5:stats:test-light:10s:1696156480",
          "stoplight:v5:stats:test-light:1s:1696156479",
          "stoplight:v5:stats:test-light:1s:1696156478",
          "stoplight:v5:stats:test-light:1s:1696156477",
          "stoplight:v5:stats:test-light:1s:1696156476",
          "stoplight:v5:stats:test-light:1s:1696156475",
          "stoplight:v5:stats:test-light:1s:1696156474",
          "stoplight:v5:stats:test-light:1s:1696156473",
          "stoplight:v5:stats:test-light:1s:1696156472"
        )
      end
    end

    context "when window_size is bigger then 60 seconds" do
      let(:window_size) { 325 }

      it "returns a mix of 60s, 10s and 1s buckets" do
        is_expected.to contain_exactly(
          "stoplight:v5:stats:test-light:60s:1696156200",
          "stoplight:v5:stats:test-light:60s:1696156260",
          "stoplight:v5:stats:test-light:60s:1696156320",
          "stoplight:v5:stats:test-light:60s:1696156380",
          "stoplight:v5:stats:test-light:60s:1696156440",

          "stoplight:v5:stats:test-light:10s:1696156180",
          "stoplight:v5:stats:test-light:10s:1696156190",

          "stoplight:v5:stats:test-light:1s:1696156172",
          "stoplight:v5:stats:test-light:1s:1696156173",
          "stoplight:v5:stats:test-light:1s:1696156174",
          "stoplight:v5:stats:test-light:1s:1696156175",
          "stoplight:v5:stats:test-light:1s:1696156176",
          "stoplight:v5:stats:test-light:1s:1696156177",
          "stoplight:v5:stats:test-light:1s:1696156178",
          "stoplight:v5:stats:test-light:1s:1696156179"
        )
      end
    end
  end

  shared_examples Stoplight::DataStore::Redis do
    it_behaves_like "Stoplight::DataStore::Base"
    it_behaves_like "Stoplight::DataStore::Base#names"
    it_behaves_like "Stoplight::DataStore::Base#get_all"
    it_behaves_like "Stoplight::DataStore::Base#record_failure"
    it_behaves_like "Stoplight::DataStore::Base#clear_failures"
    it_behaves_like "Stoplight::DataStore::Base#get_state"
    it_behaves_like "Stoplight::DataStore::Base#set_state"
    it_behaves_like "Stoplight::DataStore::Base#clear_state"

    it_behaves_like "Stoplight::DataStore::Base#get_failures" do
      context "when JSON is invalid" do
        let(:config) { Stoplight.config_provider.provide(name, error_notifier: ->(_error) {}) }

        it "handles it without an error" do
          expect(failure).to receive(:to_json).and_return("invalid JSON")

          expect { data_store.record_failure(config, failure) }
            .to change { data_store.get_failures(config) }
            .to([have_attributes(error_class: "JSON::ParserError")])
        end
      end
    end

    it_behaves_like "Stoplight::DataStore::Base#with_deduplicated_notification"
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(redis) }
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(pool) }
    let(:pool) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end

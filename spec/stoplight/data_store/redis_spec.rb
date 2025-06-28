# frozen_string_literal: true

require "connection_pool"
require "spec_helper"

RSpec.describe Stoplight::DataStore::Redis, :redis do
  let(:config) { Stoplight.default_config.with(name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Failure.new("class", "message", Time.new - 60) }
  let(:other) { Stoplight::Failure.new("class", "message 2", Time.new) }
  let(:window_size) { Stoplight::Default::WINDOW_SIZE }
  let(:cool_off_time) { Stoplight::Default::COOL_OFF_TIME }

  describe ".buckets_for_window" do
    subject(:buckets) { described_class.buckets_for_window(light_name, metric:, window_end:, window_size:) }

    let(:light_name) { "test-light" }
    let(:metric) { "failures" }

    context "when window size is smaller than the bucket size" do
      let(:window_end) { Time.at(1696156496) }
      let(:window_size) { 1000 } # Smaller than BUCKET_SIZE (3600)

      it "returns a single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:metrics:test-light:failures:1696154400"
        )
      end
    end

    context "when window size spans multiple buckets" do
      let(:window_end) { Time.at(1696154400) }
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
      let(:window_end) { Time.at(1696154400) }
      let(:window_size) { 3600 } # Exactly one bucket size

      it "returns the single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v5:metrics:test-light:failures:1696150800"
        )
      end
    end

    context "when window size is exactly one bucket size" do
      let(:window_end) { Time.at(1696156200) }
      let(:window_size) { nil }

      it "returns at most 144 buckets (1 day)" do
        is_expected.to have_attributes(count: 25)
      end
    end
  end

  shared_examples Stoplight::DataStore::Redis do
    let(:warn_on_clock_skew) { false }

    context "clock skew detection" do
      let(:stderr) { StringIO.new }
      before { $stderr = stderr }
      after { $stderr = STDERR }

      context "when clock skew warning is enabled" do
        let(:warn_on_clock_skew) { true }

        before do
          allow(data_store).to receive(:should_sample?).with(0.01).and_return(true)
        end

        context "when clock is skewed" do
          let(:current_time) { Time.now - 3600 }

          around do |example|
            Timecop.travel(current_time) do
              example.run
            end
          end

          it "produces a warning" do
            expect do
              data_store.get_metadata(config)
            end.to change(stderr, :string).to(include("Detected clock skew between Redis and the application server. Redis time:"))
          end
        end

        context "when clock is not skewed" do
          before do
            allow(data_store).to receive(:should_sample?).with(0.01).and_return(false)
          end

          it "does not produce a warning" do
            expect do
              data_store.get_metadata(config)
            end.not_to change(stderr, :string)
          end
        end
      end

      context "when clock skew warning is disabled" do
        let(:warn_on_clock_skew) { false }

        before do
          allow(data_store).to receive(:should_sample?).with(0.01).and_return(true)
        end

        context "when clock is skewed" do
          let(:current_time) { Time.now - 3600 }

          around do |example|
            Timecop.travel(current_time) do
              example.run
            end
          end

          it "does not produce a warning" do
            expect do
              data_store.get_metadata(config)
            end.not_to change(stderr, :string)
          end
        end

        context "when clock is not skewed" do
          before do
            allow(data_store).to receive(:should_sample?).with(0.01).and_return(false)
          end

          it "does not produce a warning" do
            expect do
              data_store.get_metadata(config)
            end.not_to change(stderr, :string)
          end
        end
      end
    end

    it_behaves_like "data store metrics" do
      context "when JSON is invalid" do
        let(:config) { Stoplight.default_config.with(name:, error_notifier: ->(_error) {}) }

        it "handles it without an error" do
          expect(failure).to receive(:to_json).and_return("invalid JSON")

          expect { data_store.record_failure(config, failure) }
            .to change { data_store.get_metadata(config) }
            .to(
              have_attributes(
                last_error: have_attributes(
                  error_class: "JSON::ParserError"
                )
              )
            )
        end
      end
    end

    it_behaves_like "Stoplight::DataStore::Base"
    it_behaves_like "Stoplight::DataStore::Base#names"
    it_behaves_like "Stoplight::DataStore::Base#set_state"
    it_behaves_like "Stoplight::DataStore::Base#transition_to_color"
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(redis, warn_on_clock_skew: warn_on_clock_skew) }
  end

  it_behaves_like Stoplight::DataStore::Redis do
    let(:data_store) { described_class.new(pool, warn_on_clock_skew: warn_on_clock_skew) }
    let(:pool) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end

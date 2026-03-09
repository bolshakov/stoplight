# frozen_string_literal: true

require "connection_pool"
require_relative "../data_store/recovery_metrics"
require_relative "../data_store/metrics"

RSpec.describe Stoplight::Infrastructure::Redis::DataStore, :redis do
  let(:config) { instance_double(Stoplight::Domain::Config, name:, window_size:, cool_off_time:) }
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:failure) { Stoplight::Domain::Failure.new("class", "message", Time.new - 60) }
  let(:other) { Stoplight::Domain::Failure.new("class", "message 2", Time.new) }
  let(:window_size) { 60 }
  let(:cool_off_time) { 60 }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }

  describe ".buckets_for_window" do
    subject(:buckets) { described_class.buckets_for_window(light_name, metric:, window_end:, window_size:) }

    let(:light_name) { "test-light" }
    let(:metric) { "failures" }

    context "when window size is smaller than the bucket size" do
      let(:window_end) { Time.at(1696156496) }
      let(:window_size) { 1000 } # Smaller than BUCKET_SIZE (3600)

      it "returns a single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v6:metrics:test-light:failures:1696154400"
        )
      end
    end

    context "when window size spans multiple buckets" do
      let(:window_end) { Time.at(1696154400) }
      let(:window_size) { 14400 } # Spans 4 buckets (3600s each)

      it "returns all bucket keys within the window" do
        is_expected.to contain_exactly(
          "stoplight:v6:metrics:test-light:failures:1696140000",
          "stoplight:v6:metrics:test-light:failures:1696143600",
          "stoplight:v6:metrics:test-light:failures:1696147200",
          "stoplight:v6:metrics:test-light:failures:1696150800"
        )
      end
    end

    context "when window size is exactly one bucket size" do
      let(:window_end) { Time.at(1696154400) }
      let(:window_size) { 3600 } # Exactly one bucket size

      it "returns the single bucket key" do
        is_expected.to contain_exactly(
          "stoplight:v6:metrics:test-light:failures:1696150800"
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

  describe ".new" do
    let(:redis_mock) { instance_double(Redis) }

    it "does not communicate with redis on initialization" do
      expect { described_class.new(redis: redis_mock, recovery_lock_store: nil, scripting: nil, clock:) }.not_to raise_error
    end
  end

  shared_examples Stoplight::Infrastructure::Redis::DataStore do
    let(:warn_on_clock_skew) { false }
    let(:recovery_lock_store) { instance_double(described_class::RecoveryLockStore) }
    let(:scripting) { described_class::Scripting.new(redis: connection) }

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
              data_store.get_state_snapshot(config)
            end.to change(stderr, :string).to(include("Detected clock skew between Redis and the application server. Redis time:"))
          end
        end

        context "when clock is not skewed" do
          before do
            allow(data_store).to receive(:should_sample?).with(0.01).and_return(false)
          end

          it "does not produce a warning" do
            expect do
              data_store.get_state_snapshot(config)
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
              data_store.get_state_snapshot(config)
            end.not_to change(stderr, :string)
          end
        end

        context "when clock is not skewed" do
          before do
            allow(data_store).to receive(:should_sample?).with(0.01).and_return(false)
          end

          it "does not produce a warning" do
            expect do
              data_store.get_state_snapshot(config)
            end.not_to change(stderr, :string)
          end
        end
      end
    end

    describe "#acquire_recovery_lock" do
      let(:recovery_lock) { instance_double(described_class::RecoveryLockToken) }

      it "passes control to recovery lock" do
        expect(recovery_lock_store).to receive(:acquire_lock).with(name).and_return(recovery_lock)

        acquired_lock = data_store.acquire_recovery_lock(config)
        expect(acquired_lock).to eq(recovery_lock)
      end
    end

    describe "#release_recovery_lock" do
      let(:recovery_lock) { instance_double(described_class::RecoveryLockToken) }

      it "passes control to recovery lock" do
        expect(recovery_lock_store).to receive(:release_lock).with(recovery_lock)

        data_store.release_recovery_lock(recovery_lock)
      end
    end

    it_behaves_like "Stoplight::Domain::DataStore#get_metrics"
    it_behaves_like "Stoplight::Domain::DataStore#get_recovery_metrics" do
      def get_metrics = data_store.get_recovery_metrics(config)
      def record_failure(error) = data_store.record_recovery_probe_failure(config, error)
      def record_success = data_store.record_recovery_probe_success(config)
    end
    it_behaves_like "Stoplight::Domain::DataStore#names"
    it_behaves_like "Stoplight::Domain::DataStore#set_state" do
      def set_state(state) = data_store.set_state(config, state)
      def state_snapshot = data_store.get_state_snapshot(config)
      def clear = data_store.delete_light(config)
    end
    it_behaves_like "Stoplight::Domain::DataStore#transition_to_color" do
      def transition_to_color(color) = data_store.transition_to_color(config, color)
      def state_snapshot = data_store.get_state_snapshot(config)
      def clear = data_store.delete_light(config)
    end
  end

  it_behaves_like Stoplight::Infrastructure::Redis::DataStore do
    let(:data_store) do
      described_class.new(
        clock:,
        redis: connection,
        warn_on_clock_skew: warn_on_clock_skew,
        recovery_lock_store:,
        scripting:
      )
    end
    let(:connection) { redis }
  end

  it_behaves_like Stoplight::Infrastructure::Redis::DataStore do
    let(:data_store) do
      described_class.new(
        clock:,
        redis: connection,
        warn_on_clock_skew: warn_on_clock_skew,
        recovery_lock_store:,
        scripting:
      )
    end
    let(:connection) { ConnectionPool.new(size: 1, timeout: 5, &redis_client_factory) }
  end
end

# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Registry, :redis do
  subject(:registry) { described_class.new(redis:, key_space:, clock:, config_serializer:) }

  let(:config_serializer) { Stoplight::Infrastructure::ConfigSerializer }
  let(:key_space) { Stoplight::Infrastructure::Redis::Key.new(:stoplight) }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:config) do
    instance_double(
      Stoplight::Domain::Config,
      cool_off_time: 60.0,
      threshold: 5,
      recovery_threshold: 1,
      window_size: 300,
      tracked_errors: [StandardError],
      skipped_errors: [ArgumentError],
      traffic_control: Stoplight::Domain::TrafficControl::ConsecutiveErrors.new,
      traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new
    )
  end

  describe "#names" do
    subject { registry.names }

    context "when no lights have been registered" do
      it { is_expected.to eq([]) }
    end

    context "when a light has been registered" do
      before { registry.register("stripe", config:) }

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when a light has been unregistered" do
      before do
        registry.register("stripe", config:)
        registry.unregister("stripe")
      end

      it { is_expected.not_to include("stripe") }
    end

    context "when the same light is registered twice" do
      before do
        registry.register("stripe", config:)
        registry.register("stripe", config:)
      end

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when two different lights are registered" do
      before do
        registry.register("stripe", config:)
        registry.register("paypal", config:)
      end

      it { is_expected.to contain_exactly("stripe", "paypal") }
    end
  end

  describe "#register" do
    it "persists the serialized config" do
      registry.register("stripe", config:)

      payload = redis.with { |conn| conn.hget(key_space.join("lights"), "stripe") }
      parsed = JSON.parse(payload)

      expect(parsed["config"]).to eq(Stoplight::Infrastructure::ConfigSerializer.call(config))
    end
  end

  describe "#config_for" do
    subject { registry.config_for("stripe") }

    context "when the light is registered" do
      before { registry.register("stripe", config:) }

      it "returns the persisted config" do
        is_expected.to eq(Stoplight::Infrastructure::ConfigSerializer.call(config))
      end
    end

    context "when the light was never registered" do
      it { is_expected.to be_nil }
    end
  end
end

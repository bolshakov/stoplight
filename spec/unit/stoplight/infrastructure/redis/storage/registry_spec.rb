# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Redis::Storage::Registry, :redis do
  subject(:registry) { described_class.new(redis:, key_space:, clock:, config_serializer:) }

  let(:config_serializer) { Stoplight::Infrastructure::ConfigSerializer }
  let(:key_space) { Stoplight::DataStore::Redis.key_space }
  let(:clock) { Stoplight::Infrastructure::SystemClock.new }
  let(:light_id) { SecureRandom.uuid }
  let(:config) do
    Stoplight::Domain::Config.new(
      id: light_id,
      name: "default",
      cool_off_time: 60.0,
      threshold: 5,
      recovery_threshold: 1,
      window_size: 300,
      tracked_errors: [StandardError],
      skipped_errors: [ArgumentError],
      traffic_control: Stoplight::Domain::TrafficControl::ConsecutiveErrors.new,
      traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new,
      error_notifier: nil,
      notifiers: nil,
      data_store: nil
    )
  end

  describe "#ids" do
    subject { registry.ids }

    context "when no lights have been registered" do
      it { is_expected.to eq([]) }
    end

    context "when a light has been registered" do
      before { registry.register(config.with(id: "stripe")) }

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when a light has been unregistered" do
      let(:stripe_config) { config.with(id: "stripe") }

      before do
        registry.register(stripe_config)
        registry.unregister(stripe_config.id)
      end

      it { is_expected.not_to include("stripe") }
    end

    context "when the same light is registered twice" do
      before do
        registry.register(config.with(id: "stripe"))
        registry.register(config.with(id: "stripe"))
      end

      it { is_expected.to contain_exactly("stripe") }
    end

    context "when two different lights are registered" do
      before do
        registry.register(config.with(id: "stripe"))
        registry.register(config.with(id: "paypal"))
      end

      it { is_expected.to contain_exactly("stripe", "paypal") }
    end
  end

  describe "#register" do
    let(:stripe_config) { config.with(name: "stripe") }

    it "persists the serialized config" do
      registry.register(stripe_config)

      payload = redis.with { |conn| conn.hget(key_space.join("lights"), stripe_config.id) }
      parsed = JSON.parse(payload)

      expect(parsed["config"]).to eq(Stoplight::Infrastructure::ConfigSerializer.call(stripe_config))
    end
  end

  describe "#config_for" do
    subject { registry.config_for(config.id) }

    context "when the light is registered" do
      before { registry.register(config) }

      it "returns the persisted config" do
        is_expected.to eq(Stoplight::Infrastructure::ConfigSerializer.call(config))
      end
    end

    context "when the light was never registered" do
      it { is_expected.to be_nil }
    end
  end

  describe "#all_configs" do
    subject { registry.all_configs }

    context "when the light is registered" do
      let(:config2) { config.with(id: "paypal") }

      before do
        registry.register(config)
        registry.register(config2)
      end

      it "returns all persisted configs" do
        is_expected.to contain_exactly(
          Stoplight::Infrastructure::ConfigSerializer.call(config),
          Stoplight::Infrastructure::ConfigSerializer.call(config2)
        )
      end
    end

    context "when the light was never registered" do
      it { is_expected.to be_empty }
    end

    context "when one stored record is corrupted" do
      before do
        registry.register(config)
        redis.with { |conn| conn.hset(key_space.join("lights"), "corrupted", "not json") }
      end

      it "skips the corrupted record and returns the rest" do
        is_expected.to contain_exactly(Stoplight::Infrastructure::ConfigSerializer.call(config))
      end
    end
  end
end

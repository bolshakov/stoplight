# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightFactory do
  subject(:factory) do
    described_class.new(
      system_id: Stoplight::Domain::Id.for("Test"),
      system_name: "Test",
      config:,
      failover_system:,
      telemetry: bus
    )
  end

  let(:failover_system) do
    Stoplight::Wiring::System.new(
      config: Stoplight::Wiring::FailSafeConfig.with(name: SecureRandom.uuid),
      failover_system: nil,
      registry: instance_double(Stoplight::Infrastructure::Memory::Storage::Registry, register: nil)
    )
  end

  let(:config) do
    Stoplight::Wiring::LightConfigurationDsl.new(
      name: "stripe",
      tracked_errors: [ArgumentError],
      skipped_errors: [TypeError],
      traffic_control: :error_rate,
      threshold: 0.5,
      window_size: 60,
      traffic_recovery: :consecutive_successes
    ).configure!(Stoplight::Wiring::DefaultConfig)
  end

  let(:bus) { Stoplight::Domain::Telemetry::Bus.new(error_notifier: ->(error) { raise error }) }
  let(:received) { [] }

  before { bus.subscribe(Stoplight::Domain::Telemetry::LightRegistered) { |envelope| received << envelope } }

  describe "#build" do
    context "with a Redis data store", :redis do
      let(:data_store) { Stoplight::DataStore::Redis.new(redis) }
      let(:config) { super().with(data_store:) }
      let(:other_factory) do
        described_class.new(
          system_id: Stoplight::Domain::Id.for("Test"),
          system_name: "Test",
          config: config.with(name: "PayPay"),
          failover_system:,
          telemetry: bus
        )
      end

      before do
        allow(Stoplight::Infrastructure::Redis::Storage::Scripting).to receive(:new).and_call_original
      end

      it "shares the data store's script cache between lights" do
        expect(Stoplight::Infrastructure::Redis::Storage::Scripting).to receive(:new).once

        factory.build
        other_factory.build
      end
    end

    it "emits exactly one LightRegistered event" do
      factory.build

      expect(received.size).to eq(1)
    end

    it "maps the resolved config onto a Settings snapshot" do
      factory.build

      settings = received.first.payload.settings
      expect(settings).to have_attributes(
        cool_off_time: config.cool_off_time,
        threshold: 0.5,
        recovery_threshold: config.recovery_threshold,
        window_size: 60,
        tracked_errors: ["ArgumentError"],
        skipped_errors: ["TypeError"],
        traffic_control: "error_rate",
        traffic_control_params: {},
        traffic_recovery: "consecutive_successes",
        traffic_recovery_params: {}
      )
    end

    it "returns the fully constructed light" do
      light = factory.build

      expect(light).to be_a(Stoplight::Domain::Light)
      expect(light.name).to eq("stripe")
    end
  end
end

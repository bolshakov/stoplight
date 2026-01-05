# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::System do
  subject(:system) { described_class.new("system name", settings:) }
  let(:settings) do
    Stoplight::Wiring::Settings.new(
      name: Stoplight::Common.none,
      cool_off_time:,
      threshold:,
      recovery_threshold:,
      window_size:,
      tracked_errors:,
      skipped_errors:,
      data_store:,
      error_notifier:,
      notifiers:,
      traffic_control:,
      traffic_recovery:
    )
  end
  let(:cool_off_time) { Stoplight::Common.none }
  let(:threshold) { Stoplight::Common.none }
  let(:recovery_threshold) { Stoplight::Common.none }
  let(:window_size) { Stoplight::Common.none }
  let(:tracked_errors) { Stoplight::Common.none }
  let(:skipped_errors) { Stoplight::Common.none }
  let(:data_store) { Stoplight::Common.none }
  let(:error_notifier) { Stoplight::Common.none }
  let(:notifiers) { Stoplight::Common.none }
  let(:traffic_control) { Stoplight::Common.none }
  let(:traffic_recovery) { Stoplight::Common.none }

  describe "#new" do
    let(:traffic_control) { Stoplight::Common.some(:error_rate) }
    let(:threshold) { Stoplight::Common.some(1) }

    it "validates system configuration" do
      expect { system }.to raise_error(Stoplight::Error::ConfigurationError)
    end
  end

  describe "#light" do
    let(:name) { SecureRandom.uuid }

    context "when a new light" do
      subject(:light) { system.light(name) }

      it "creates a new light" do
        is_expected.to be_kind_of(Stoplight::Domain::Light)
      end
    end

    context "when the light is already exists with the same name" do
      subject(:light) { system.light(name) }

      it "returns the same light instance" do
        existing_light = system.light(name)
        expect(light).to be(existing_light)
      end
    end

    context "when the light is already exists with the same name yet different settings" do
      subject(:light) { system.light(name, window_size: 244) }

      it "raises configuration error" do
        system.light(name, window_size: 422)
        expect { light }.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    context "when requesting existing light" do
      subject(:light) { system.light(name) }

      it "raises configuration error" do
        system.light(name, window_size: 422)
        expect { light }.to raise_error(Stoplight::Error::ConfigurationError)
      end
    end

    context "when the light is already exists with the same name and settings" do
      subject(:light) { system.light(name, window_size: 422) }

      it "returns the same light" do
        existing_light = system.light(name, window_size: 422)

        is_expected.to be(existing_light)
      end
    end

    context "when the light with the same name exists in another system" do
      subject(:light) { system.light(name, window_size: 422) }

      it "allows same name light in different systems" do
        another_system = described_class.new("another system", settings: Stoplight::Wiring::Settings.empty)
        existing_light = another_system.light(name, window_size: 224)

        expect(light).not_to be(existing_light)
      end
    end

    context "when extending existing light" do
      subject(:light) { system.light(name) }

      it "raises configuration error" do
        expect do
          light.with(window_size: 422)
        end.to raise_error(NotImplementedError, "You're not allowed to extend system lights")
      end
    end

    context "with cool_off_time" do
      subject(:config) { light.config }

      let(:light) { system.light(name, cool_off_time: 42) }

      it "sets cool_off_time" do
        is_expected.to have_attributes(cool_off_time: 42)
      end
    end

    context "with recovery_threshold" do
      subject(:config) { light.config }

      let(:light) { system.light(name, recovery_threshold: 14) }

      it "sets recovery_threshold" do
        is_expected.to have_attributes(recovery_threshold: 14)
      end
    end

    context "with threshold" do
      subject(:config) { light.config }

      let(:light) { system.light(name, threshold: 14) }

      it "sets threshold" do
        is_expected.to have_attributes(threshold: 14)
      end
    end

    context "with window_size" do
      subject(:config) { light.config }

      let(:light) { system.light(name, window_size: 60) }

      it "sets window_size" do
        is_expected.to have_attributes(window_size: 60)
      end
    end

    context "with name" do
      subject(:config) { light.config }

      let(:light) { system.light(name) }

      it "sets name" do
        is_expected.to have_attributes(name:)
      end
    end

    context "with skipped_errors" do
      subject(:config) { light.config }

      let(:light) { system.light(name, skipped_errors: light_skipped_errors) }
      let(:light_skipped_errors) { [StandardError, KeyError] }

      it "sets skipped_errors" do
        is_expected.to have_attributes(skipped_errors: light_skipped_errors)
      end
    end

    context "with tracked_errors" do
      subject(:config) { light.config }

      let(:light) { system.light(name, tracked_errors: light_tracked_errors) }
      let(:light_tracked_errors) { [StandardError, KeyError] }

      it "sets tracked_errors" do
        is_expected.to have_attributes(tracked_errors: light_tracked_errors)
      end
    end

    context "with traffic_control" do
      subject(:light) do
        system.light(name,
          traffic_control: {error_rate: {min_requests: 2}},
          threshold: 0.5,
          window_size: 30)
      end

      it "sets traffic_control" do
        light.run(->(_) {}) { raise }
        expect(light.color).to eq("green")

        light.run(->(_) {}) { raise }
        expect(light.color).to eq("red")
      end
    end

    context "with traffic_recovery" do
      subject(:light) do
        system.light(name,
          traffic_recovery: :consecutive_successes,
          recovery_threshold: 2,
          cool_off_time: 0.1,
          threshold: 1)
      end

      it "sets traffic_control" do
        while light.color == "green"
          light.run(->(_) {}) { raise }
        end
        sleep 0.1

        light.run {}
        expect(light.color).to eq("yellow")
        light.run {}
        expect(light.color).to eq("green")
      end
    end

    context "with data_store" do
      subject(:light) { system.light(name, data_store: Stoplight::DataStore::Memory.new) }

      it "raises an error" do
        expect { light }.to raise_error(ArgumentError)
      end
    end
  end
end

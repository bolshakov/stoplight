# frozen_string_literal: true

RSpec.describe Stoplight::Light do
  let(:config) { Stoplight.config_provider.provide(random_string) }
  let(:light) { Stoplight::Light.new(config) }
  let(:failure) do
    Stoplight::Failure.new(error.class_name, error.message, time)
  end
  let(:error) { error_class.new(error_message) }
  let(:error_class) { Class.new(StandardError) }
  let(:error_message) { random_string }
  let(:time) { Time.new }

  def random_string
    ("a".."z").to_a.sample(8).join
  end

  describe "#==" do
    let(:light) { Stoplight("foo") }
    let(:light_with_the_same_name) { Stoplight("foo") }
    let(:light_with_different_name) { Stoplight("bar") }
    let(:light_with_different_config) { Stoplight("foo").with_cool_off_time(10) }

    it "returns true when the lights have the same configuration" do
      expect(light == light_with_the_same_name).to eq(true)
      expect(light == light_with_different_name).to eq(false)
      expect(light == light_with_different_config).to eq(false)
      expect(light.with_cool_off_time(10) == light_with_different_config).to eq(true)
    end
  end

  describe "#lock" do
    let(:color) { Stoplight::Color::GREEN }

    context "with correct color" do
      it "returns the light" do
        expect(light.lock(color)).to be_a Stoplight::Light
      end

      context "with green color" do
        let(:color) { Stoplight::Color::GREEN }

        it "locks green color" do
          expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_GREEN)

          light.lock(color)
        end
      end

      context "with red color" do
        let(:color) { Stoplight::Color::RED }

        it "locks red color" do
          expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_RED)

          light.lock(color)
        end
      end
    end

    context "with incorrect color" do
      let(:color) { "incorrect-color" }

      it "raises Error::IncorrectColor error" do
        expect { light.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end

      it "does not lock color" do
        expect(config.data_store).to_not receive(:set_state)

        suppress(Stoplight::Error::IncorrectColor) { light.lock(color) }
      end
    end
  end

  describe "#unlock" do
    it "returns the light" do
      expect(light.unlock).to be_a Stoplight::Light
    end

    context "with locked green light" do
      before { light.lock(Stoplight::Color::GREEN) }

      it "unlocks light" do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end

    context "with locked red light" do
      before { light.lock(Stoplight::Color::RED) }

      it "unlocks light" do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end

    context "with unlocked light" do
      it "unlocks light" do
        expect(config.data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        light.unlock
      end
    end
  end

  describe "#with" do
    let(:settings) do
      {
        name: "combined-light",
        threshold: 5,
        window_size: 60,
        tracked_errors: [RuntimeError],
        skipped_errors: [KeyError, NoMemoryError, ScriptError, SecurityError, SignalException, SystemExit, SystemStackError]
      }
    end

    subject(:with_combined_settings) { light.with(**settings) }

    it "applies all settings correctly" do
      expect(with_combined_settings.config).to have_attributes(**settings)
    end
  end

  context "with memory data store" do
    let(:config) { Stoplight.config_provider.provide(random_string, data_store:) }
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end

  context "with redis data store", :redis do
    let(:config) { Stoplight.config_provider.provide(random_string, data_store:) }
    let(:data_store) { Stoplight::DataStore::Redis.new(redis) }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end
end

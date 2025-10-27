# frozen_string_literal: true

RSpec.describe Stoplight::Light do
  let(:light) do
    described_class.new(
      config,
      green_run_strategy:,
      yellow_run_strategy:,
      red_run_strategy:,
      factory:,
      data_store:
    )
  end
  let(:factory) { instance_double(Stoplight::Domain::LightFactory) }
  let(:config) do
    Stoplight::Domain::Config.empty.with(
      name: random_string,
      cool_off_time: 60
    )
  end
  let(:green_run_strategy) { instance_double(Stoplight::Domain::Strategies::GreenRunStrategy) }
  let(:yellow_run_strategy) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }
  let(:red_run_strategy) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }
  let(:data_store) { Stoplight::DataStore::Memory.new }

  def random_string
    ("a".."z").to_a.sample(8).join
  end

  describe "#==" do
    let(:light) { Stoplight("foo") }
    let(:light_with_the_same_name) { Stoplight("foo") }
    let(:light_with_different_name) { Stoplight("bar") }
    let(:light_with_different_config) { Stoplight("foo", cool_off_time: 10) }

    it "returns true when the lights have the same configuration" do
      expect(light == light_with_the_same_name).to eq(true)
      expect(light == light_with_different_name).to eq(false)
      expect(light == light_with_different_config).to eq(false)
      expect(light.with(cool_off_time: 10) == light_with_different_config).to eq(true)
    end
  end

  describe "#lock" do
    let(:color) { Stoplight::Color::GREEN }

    context "with correct color" do
      context "with green color" do
        let(:color) { Stoplight::Color::GREEN }

        it "locks green color" do
          expect(data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_GREEN)

          expect(light.lock(color)).to be_a Stoplight::Light
        end
      end

      context "with red color" do
        let(:color) { Stoplight::Color::RED }

        it "locks red color" do
          expect(data_store).to receive(:set_state).with(config, Stoplight::State::LOCKED_RED)

          expect(light.lock(color)).to be_a Stoplight::Light
        end
      end
    end

    context "with incorrect color" do
      let(:color) { "incorrect-color" }

      it "raises Error::IncorrectColor error" do
        expect { light.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end

      it "does not lock color" do
        expect(data_store).to_not receive(:set_state)

        suppress(Stoplight::Error::IncorrectColor) { light.lock(color) }
      end
    end
  end

  describe "#unlock" do
    context "with locked green light" do
      before { light.lock(Stoplight::Color::GREEN) }

      it "unlocks light" do
        expect(data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        expect(light.unlock).to be_a Stoplight::Light
      end
    end

    context "with locked red light" do
      before { light.lock(Stoplight::Color::RED) }

      it "unlocks light" do
        expect(data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

        expect(light.unlock).to be_a Stoplight::Light
      end
    end

    context "with unlocked light" do
      it "unlocks light" do
        expect(data_store).to receive(:set_state).with(config, Stoplight::State::UNLOCKED)

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

    it "applies all settings correctly" do
      new_light = instance_double(Stoplight::Light)
      expect(factory).to receive(:build_with).with(**settings).and_return(new_light)

      expect(light.with(**settings)).to eq(new_light)
    end
  end

  context "with memory data store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end

  context "with redis data store", :redis do
    let(:data_store) { Stoplight::Infrastructure::DataStore::Redis.new(redis) }

    it_behaves_like "Stoplight::Light#state"
    it_behaves_like "Stoplight::Light#color"
    it_behaves_like "Stoplight::Light#run"
  end
end

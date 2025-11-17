# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Light do
  subject(:light) do
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
  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:green_run_strategy) { instance_double(Stoplight::Domain::Strategies::GreenRunStrategy) }
  let(:yellow_run_strategy) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }
  let(:red_run_strategy) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

  describe "#==" do
    context "light with the same dependencies" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          factory:,
          data_store:
        )
      end

      it { expect(light).to eq(light_2) }
    end

    context "light with the different configs" do
      let(:light_2) do
        described_class.new(
          config2,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          factory:,
          data_store:
        )
      end
      let(:config2) { instance_double(Stoplight::Domain::Config) }

      it { expect(light).not_to eq(light_2) }
    end

    context "light with the different green run strategy" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy: green_run_strategy2,
          yellow_run_strategy:,
          red_run_strategy:,
          factory:,
          data_store:
        )
      end
      let(:green_run_strategy2) { instance_double(Stoplight::Domain::Strategies::GreenRunStrategy) }

      it { expect(light).not_to eq(light_2) }
    end

    context "light with the different red run strategy" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy: red_run_strategy2,
          yellow_run_strategy:,
          red_run_strategy:,
          factory:,
          data_store:
        )
      end
      # let(:yellow_run_strategy) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }
      let(:red_run_strategy2) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }
      # let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

      it { expect(light).not_to eq(light_2) }
    end

    context "light with the different yellow run strategy" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy:,
          yellow_run_strategy: yellow_run_strategy2,
          red_run_strategy:,
          factory:,
          data_store:
        )
      end
      let(:yellow_run_strategy2) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }

      it { expect(light).not_to eq(light_2) }
    end

    context "light with the different data storey" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          factory:,
          data_store: data_store2
        )
      end
      let(:data_store2) { instance_double(Stoplight::Domain::DataStore) }

      it { expect(light).not_to eq(light_2) }
    end

    context "light with the different factory" do
      let(:light_2) do
        described_class.new(
          config,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:,
          factory: factory2,
          data_store:
        )
      end
      let(:factory2) { instance_double(Stoplight::Domain::LightFactory) }

      it { expect(light).not_to eq(light_2) }
    end
  end

  describe "#lock" do
    let(:color) { Stoplight::Domain::Color::GREEN }

    context "with correct color" do
      context "with green color" do
        let(:color) { Stoplight::Domain::Color::GREEN }

        it "locks green color" do
          expect(data_store).to receive(:set_state).with(config, Stoplight::Domain::State::LOCKED_GREEN)

          expect(light.lock(color)).to be_a Stoplight::Domain::Light
        end
      end

      context "with red color" do
        let(:color) { Stoplight::Domain::Color::RED }

        it "locks red color" do
          expect(data_store).to receive(:set_state).with(config, Stoplight::Domain::State::LOCKED_RED)

          expect(light.lock(color)).to be_a Stoplight::Domain::Light
        end
      end
    end

    context "with incorrect color" do
      let(:color) { "incorrect-color" }

      it "raises Error::IncorrectColor error" do
        expect { light.lock(color) }.to raise_error(Stoplight::Domain::Error::IncorrectColor)
      end

      it "does not lock color" do
        expect(data_store).to_not receive(:set_state)

        suppress(Stoplight::Domain::Error::IncorrectColor) { light.lock(color) }
      end
    end
  end

  specify "#unlock" do
    expect(data_store).to receive(:set_state).with(config, Stoplight::Domain::State::UNLOCKED)

    expect(light.unlock).to be_a Stoplight::Domain::Light
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

    it "delegates to the factory" do
      new_light = instance_double(Stoplight::Domain::Light)
      expect(factory).to receive(:build_with).with(**settings).and_return(new_light)

      expect(light.with(**settings)).to eq(new_light)
    end

    it "produces deprecation warning" do
      allow(factory).to receive(:build_with)

      expect { light.with(**settings) }.to output(
        include("[DEPRECATION] Light#with is deprecated and will be removed in v6.0.0.")
      ).to_stderr
    end
  end

  specify "#state" do
    state_snapshot = instance_double(Stoplight::Domain::StateSnapshot, locked_state: "LOCKED_STATE")
    expect(data_store).to receive(:get_state_snapshot).and_return(state_snapshot)

    expect(light.state).to eq("LOCKED_STATE")
  end

  specify "#color" do
    state_snapshot = instance_double(Stoplight::Domain::StateSnapshot, color: "COLOR")
    expect(data_store).to receive(:get_state_snapshot).and_return(state_snapshot)

    expect(light.color).to eq("COLOR")
  end

  describe "#run" do
    let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color:) }
    let(:fallback) { ->(_error) { "fallback" } }
    let(:code) { -> { "result" } }

    before do
      expect(data_store).to receive(:get_state_snapshot).with(config).and_return(state_snapshot)
    end

    shared_examples "delegates to the run strategy" do |current_color|
      context "when #{current_color} color" do
        let(:color) { current_color }

        it "executes green run strategy" do
          expect(strategy).to receive(:execute).with(fallback, state_snapshot:) { |_, _, &block|
            expect(block).to eq(code)
            "result"
          }

          expect(light.run(fallback, &code)).to eq("result")
        end
      end
    end

    it_behaves_like "delegates to the run strategy", Stoplight::Domain::Color::GREEN do
      let(:strategy) { green_run_strategy }
    end

    it_behaves_like "delegates to the run strategy", Stoplight::Domain::Color::YELLOW do
      let(:strategy) { yellow_run_strategy }
    end

    it_behaves_like "delegates to the run strategy", Stoplight::Domain::Color::RED do
      let(:strategy) { red_run_strategy }
    end
  end
end

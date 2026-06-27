# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Light do
  subject(:light) do
    described_class.new(
      config,
      green_run_strategy:,
      yellow_run_strategy:,
      red_run_strategy:,
      state_store:
    )
  end
  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:green_run_strategy) { instance_double(Stoplight::Domain::Strategies::GreenRunStrategy) }
  let(:yellow_run_strategy) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }
  let(:red_run_strategy) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }
  let(:state_store) { instance_double(NullStateStore) }

  describe "#lock" do
    let(:color) { Stoplight::Color::GREEN }

    context "with correct color" do
      context "with green color" do
        let(:color) { Stoplight::Color::GREEN }

        it "locks green color" do
          expect(state_store).to receive(:set_state).with(Stoplight::State::LOCKED_GREEN)

          expect(light.lock(color)).to be_a Stoplight::Domain::Light
        end
      end

      context "with red color" do
        let(:color) { Stoplight::Color::RED }

        it "locks red color" do
          expect(state_store).to receive(:set_state).with(Stoplight::State::LOCKED_RED)

          expect(light.lock(color)).to be_a Stoplight::Domain::Light
        end
      end
    end

    context "with incorrect color" do
      let(:color) { "incorrect-color" }

      it "raises Error::IncorrectColor error" do
        expect { light.lock(color) }.to raise_error(Stoplight::Error::IncorrectColor)
      end

      it "does not lock color" do
        expect(state_store).to_not receive(:set_state)

        suppress(Stoplight::Error::IncorrectColor) { light.lock(color) }
      end
    end
  end

  specify "#unlock" do
    expect(state_store).to receive(:set_state).with(Stoplight::State::UNLOCKED)

    expect(light.unlock).to be_a Stoplight::Domain::Light
  end

  specify "#state" do
    state_snapshot = instance_double(Stoplight::Domain::StateSnapshot, locked_state: "LOCKED_STATE")
    expect(state_store).to receive(:state_snapshot).and_return(state_snapshot)

    expect(light.state).to eq("LOCKED_STATE")
  end

  specify "#color" do
    state_snapshot = instance_double(Stoplight::Domain::StateSnapshot, color: "COLOR")
    expect(state_store).to receive(:state_snapshot).and_return(state_snapshot)

    expect(light.color).to eq("COLOR")
  end

  describe "#run" do
    let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot, color:) }
    let(:fallback) { ->(_error) { "fallback" } }
    let(:code) { -> { "result" } }

    before do
      expect(state_store).to receive(:state_snapshot).and_return(state_snapshot)
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

    it_behaves_like "delegates to the run strategy", Stoplight::Color::GREEN do
      let(:strategy) { green_run_strategy }
    end

    it_behaves_like "delegates to the run strategy", Stoplight::Color::YELLOW do
      let(:strategy) { yellow_run_strategy }
    end

    it_behaves_like "delegates to the run strategy", Stoplight::Color::RED do
      let(:strategy) { red_run_strategy }
    end
  end
end

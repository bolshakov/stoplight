# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Light do
  subject(:light) do
    described_class.new(
      config,
      green_run_strategy:,
      yellow_run_strategy:,
      red_run_strategy:,
      state_store:,
      lock_control:,
      error_tracking_policy:
    )
  end
  let(:config) { instance_double(Stoplight::Domain::Config) }
  let(:green_run_strategy) { instance_double(Stoplight::Domain::Strategies::GreenRunStrategy) }
  let(:yellow_run_strategy) { instance_double(Stoplight::Domain::Strategies::YellowRunStrategy) }
  let(:red_run_strategy) { instance_double(Stoplight::Domain::Strategies::RedRunStrategy) }
  let(:state_store) { instance_double(NullStateStore) }
  let(:lock_control) { instance_double(Stoplight::Domain::LockControl) }
  let(:error_tracking_policy) do
    Stoplight::Domain::ErrorTrackingPolicy.new(tracked: [StandardError], skipped: [Timeout::Error])
  end

  describe "#lock" do
    let(:color) { Stoplight::Color::GREEN }

    it "delegates to lock_control" do
      expect(lock_control).to receive(:lock).with(color)

      expect(light.lock(color)).to be_a Stoplight::Domain::Light
    end
  end

  specify "#unlock" do
    expect(lock_control).to receive(:unlock)

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
    let(:color) { Stoplight::Color::GREEN }
    let(:fallback) { ->(_error) { "fallback" } }
    let(:code) { -> { "result" } }

    before do
      expect(state_store).to receive(:state_snapshot).and_return(state_snapshot)
    end

    shared_examples "delegates to the run strategy" do |current_color|
      context "when #{current_color} color" do
        let(:color) { current_color }

        it "executes green run strategy" do
          expect(strategy).to receive(:execute).with(fallback, state_snapshot:, error_tracking_policy:) { |_, _, &block|
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

    it "uses per-call overrides with registered values as partial fallbacks" do
      expect(green_run_strategy).to receive(:execute).with(
        fallback,
        state_snapshot:,
        error_tracking_policy: satisfy { |policy|
          policy.track?(KeyError.new) &&
            !policy.track?(ArgumentError.new) &&
            !policy.track?(Timeout::Error.new)
        }
      ) { "result" }

      expect(light.run(fallback, tracked_errors: [KeyError], &code)).to eq("result")
    end
  end
end

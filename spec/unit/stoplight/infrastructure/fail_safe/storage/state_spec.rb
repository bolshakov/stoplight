# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::FailSafe::Storage::State do
  let(:fail_safe) do
    described_class.new(
      primary_store:, error_notifier:, failover_store:,
      circuit_breaker: test_circuit_breaker_class.new
    )
  end
  let(:failover_store) { instance_double(NullStateStore) }
  let(:primary_store) { instance_double(NullStateStore) }
  let(:error_notifier) { instance_double(Proc) }

  let(:test_circuit_breaker_class) do
    Class.new(Stoplight::Domain::Light) do
      def initialize
      end

      def run(fallback)
        yield
      rescue => exception
        fallback.call(exception)
      end
    end
  end

  describe "#set_state" do
    subject { fail_safe.set_state(state) }

    context "when primary store does not fail" do
      let(:state) { instance_double(String) }

      it "returns state from primary store" do
        expect(primary_store).to receive(:set_state).with(state).and_return(state)

        is_expected.to eq(state)
      end
    end

    context "when primary store fails" do
      let(:error) { StandardError.new("Test error") }
      let(:state) { instance_double(String) }

      it "sets state on failover state" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:set_state).with(state) { raise error }
        expect(failover_store).to receive(:set_state).with(state).and_return(state)

        is_expected.to eq(state)
      end
    end
  end

  describe "#state_snapshot" do
    subject { fail_safe.state_snapshot }

    context "when primary store does not fail" do
      let(:state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot) }

      it "returns state snapshot from primary store" do
        expect(primary_store).to receive(:state_snapshot).and_return(state_snapshot)

        is_expected.to eq(state_snapshot)
      end
    end

    context "when store fails" do
      let(:error) { StandardError.new("Test error") }
      let(:failover_state_snapshot) { instance_double(Stoplight::Domain::StateSnapshot) }

      it "sets state on failover state" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:state_snapshot) { raise error }
        expect(failover_store).to receive(:state_snapshot).and_return(failover_state_snapshot)

        is_expected.to eq(failover_state_snapshot)
      end
    end
  end

  describe "#transition_to_color" do
    subject { fail_safe.transition_to_color(color) }

    let(:color) { Stoplight::Color::GREEN }
    let(:transition_result) { rand }

    context "when primary store does not fail" do
      it "returns the transition result" do
        expect(primary_store).to receive(:transition_to_color).with(color).and_return(transition_result)

        is_expected.to eq(transition_result)
      end
    end

    context "when primary store fails" do
      let(:error) { StandardError.new("Test error") }

      it "returns result from failover" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:transition_to_color).with(color).and_raise(error)
        expect(failover_store).to receive(:transition_to_color).with(color).and_return(transition_result)

        is_expected.to eq(transition_result)
      end
    end
  end

  describe "#clear" do
    subject(:clear) { fail_safe.clear }

    context "when primary store does not fail" do
      it "clears state in the primary store" do
        expect(primary_store).to receive(:clear)

        clear
      end
    end

    context "when primary store fails" do
      let(:error) { StandardError.new("Test error") }

      it "sets state on failover state" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:clear) { raise error }
        expect(failover_store).to receive(:clear)

        clear
      end
    end
  end
end

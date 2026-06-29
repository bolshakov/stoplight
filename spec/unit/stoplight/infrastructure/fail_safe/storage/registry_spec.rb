# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::FailSafe::Storage::Registry do
  let(:fail_safe) do
    described_class.new(
      primary_registry:, error_notifier:, failover_registry:,
      circuit_breaker:
    )
  end
  let(:primary_registry) { instance_double(Stoplight::Infrastructure::Redis::Storage::Registry) }
  let(:failover_registry) { instance_double(Stoplight::Infrastructure::Memory::Storage::Registry) }
  let(:error_notifier) { instance_double(Proc) }
  let(:circuit_breaker) { closed_circuit_breaker_class.new }

  # Simulates a healthy circuit: runs the block, rescues and delegates to fallback on error.
  let(:closed_circuit_breaker_class) do
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

  # Simulates an open circuit: skips the block entirely and calls fallback with nil.
  let(:open_circuit_breaker_class) do
    Class.new(Stoplight::Domain::Light) do
      def initialize
      end

      def run(fallback)
        fallback.call(nil)
      end
    end
  end

  describe "#names" do
    subject { fail_safe.names }

    context "when primary registry does not fail" do
      it "returns names from primary registry" do
        expect(primary_registry).to receive(:names).and_return(["stripe"])

        is_expected.to eq(["stripe"])
      end
    end

    context "when primary registry fails" do
      let(:error) { StandardError.new("connection refused") }

      it "notifies the error and returns names from the failover registry" do
        expect(primary_registry).to receive(:names).and_raise(error)
        expect(error_notifier).to receive(:call).with(error)
        expect(failover_registry).to receive(:names).and_return([])

        is_expected.to eq([])
      end
    end

    context "when the circuit is open" do
      let(:circuit_breaker) { open_circuit_breaker_class.new }

      it "does not notify and returns names from the failover registry" do
        expect(primary_registry).not_to receive(:names)
        expect(error_notifier).not_to receive(:call)
        expect(failover_registry).to receive(:names).and_return([])

        is_expected.to eq([])
      end
    end
  end

  describe "#register" do
    subject(:register) { fail_safe.register("stripe", config: nil) }

    context "when primary registry does not fail" do
      it "delegates to primary registry" do
        expect(primary_registry).to receive(:register).with("stripe", config: nil)

        register
      end
    end

    context "when primary registry fails" do
      let(:error) { StandardError.new("connection refused") }

      it "notifies the error and falls back to the failover registry" do
        expect(primary_registry).to receive(:register).with("stripe", config: nil).and_raise(error)
        expect(error_notifier).to receive(:call).with(error)
        expect(failover_registry).to receive(:register).with("stripe", config: nil)

        register
      end
    end

    context "when the circuit is open" do
      let(:circuit_breaker) { open_circuit_breaker_class.new }

      it "does not notify and falls back to the failover registry" do
        expect(primary_registry).not_to receive(:register)
        expect(error_notifier).not_to receive(:call)
        expect(failover_registry).to receive(:register).with("stripe", config: nil)

        register
      end
    end
  end

  describe "#unregister" do
    subject(:unregister) { fail_safe.unregister("stripe") }

    context "when primary registry does not fail" do
      it "delegates to primary registry" do
        expect(primary_registry).to receive(:unregister).with("stripe")

        unregister
      end
    end

    context "when primary registry fails" do
      let(:error) { StandardError.new("connection refused") }

      it "notifies the error and falls back to the failover registry" do
        expect(primary_registry).to receive(:unregister).with("stripe").and_raise(error)
        expect(error_notifier).to receive(:call).with(error)
        expect(failover_registry).to receive(:unregister).with("stripe")

        unregister
      end
    end

    context "when the circuit is open" do
      let(:circuit_breaker) { open_circuit_breaker_class.new }

      it "does not notify and falls back to the failover registry" do
        expect(primary_registry).not_to receive(:unregister)
        expect(error_notifier).not_to receive(:call)
        expect(failover_registry).to receive(:unregister).with("stripe")

        unregister
      end
    end
  end
end

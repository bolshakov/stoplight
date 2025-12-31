# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::Storage::FailSafe::Metrics do
  let(:fail_safe) do
    described_class.new(
      primary_store:, error_notifier:, failover_store:,
      circuit_breaker: test_circuit_breaker_class.new
    )
  end
  let(:failover_store) { instance_double(Stoplight::Domain::Storage::Metrics) }
  let(:primary_store) { instance_double(Stoplight::Domain::Storage::Metrics) }
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

  describe "#metrics_snapshot" do
    subject { fail_safe.metrics_snapshot }

    context "when primary store does not fail" do
      let(:metrics_snapshot) { instance_double(Stoplight::Domain::MetricsSnapshot) }

      it "returns metrics snapshot from primary store" do
        expect(primary_store).to receive(:metrics_snapshot).and_return(metrics_snapshot)

        is_expected.to eq(metrics_snapshot)
      end
    end

    context "when store fails" do
      let(:error) { StandardError.new("Test error") }
      let(:failover_metrics_snapshot) { instance_double(Stoplight::Domain::MetricsSnapshot) }

      it "sets state on failover state" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:metrics_snapshot) { raise error }
        expect(failover_store).to receive(:metrics_snapshot).and_return(failover_metrics_snapshot)

        is_expected.to eq(failover_metrics_snapshot)
      end
    end
  end

  describe "#record_success" do
    subject(:record_success) { fail_safe.record_success }

    context "when primary store does not fail" do
      it "records success" do
        expect(primary_store).to receive(:record_success)

        record_success
      end
    end

    context "when primary store fails" do
      let(:error) { StandardError.new("Test error") }

      it "delegates to failover" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:record_success).and_raise(error)
        expect(failover_store).to receive(:record_success)

        record_success
      end
    end
  end

  describe "#record_failure" do
    subject(:record_failure) { fail_safe.record_failure(exception) }
    let(:exception) { RuntimeError.new }

    context "when primary store does not fail" do
      it "record failure" do
        expect(primary_store).to receive(:record_failure)

        record_failure
      end
    end

    context "when primary store fails" do
      let(:error) { StandardError.new("Test error") }

      it "delegates to failover" do
        expect(error_notifier).to receive(:call).with(error)
        expect(primary_store).to receive(:record_failure).with(exception).and_raise(error)
        expect(failover_store).to receive(:record_failure).with(exception)

        record_failure
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

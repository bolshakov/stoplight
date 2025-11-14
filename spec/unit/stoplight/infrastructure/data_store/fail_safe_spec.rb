# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::DataStore::FailSafe do
  let(:fail_safe) do
    described_class.new(
      data_store:, error_notifier:, failover_data_store:,
      circuit_breaker: test_circuit_breaker_class.new
    )
  end
  let(:failover_data_store) { Stoplight::Infrastructure::DataStore::Memory.new }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size: 4, cool_off_time: 60, threshold: 3) }
  let(:error_notifier) { instance_double(Proc) }
  let(:name) { SecureRandom.uuid }
  let(:error) { StandardError.new("Test error") }

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

  it_behaves_like "Stoplight::Domain::DataStore"

  describe "#names" do
    subject { fail_safe.names }

    context "when data_store returns names" do
      let(:names) { ["foo", "bar"] }

      it "returns names from data_store" do
        expect(data_store).to receive(:names).and_return(names)

        is_expected.to eq(names)
      end
    end

    context "when data_store fails" do
      it "returns empty list of names" do
        expect(data_store).to receive(:names) { raise error }

        is_expected.to be_kind_of(Array)
      end
    end
  end

  describe "#delete_light" do
    subject(:delete_light) { fail_safe.delete_light(config) }

    context "when data_store deletes metadata" do
      it "delegates to data_store without notifying error_notifier" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:delete_light).with(config)

        delete_light
      end
    end

    context "when data_store fails" do
      it "uses failover data store and notifies error_notifier" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:delete_light).with(config) { raise error }
        expect(failover_data_store).to receive(:delete_light).with(config)

        delete_light
      end
    end
  end

  describe "#record_failure" do
    subject(:record_failure) { fail_safe.record_failure(config, error) }

    let(:error) { KeyError.new("unexpected key") }

    context "when data_store records failure" do
      it "returns total number of errors from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_failure).with(config, error).and_return(4)

        is_expected.to eq(4)
      end
    end

    context "when data_store fails" do
      it "returns empty list of errors" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:record_failure).with(config, error) { raise error }

        record_failure
      end
    end
  end

  describe "#record_success" do
    subject(:record_success) { fail_safe.record_success(config) }

    context "when data_store records failure" do
      it "delegates to data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_success).with(config)

        record_success
      end
    end

    context "when data_store fails" do
      it "does not fail" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:record_success).with(config) { raise error }

        record_success
      end
    end
  end

  describe "#record_recovery_probe_failure" do
    subject(:record_recovery_probe_failure) { fail_safe.record_recovery_probe_failure(config, error) }

    let(:error) { KeyError.new("unexpected key") }

    context "when data_store records recovery probe failure" do
      it "returns metadata from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_recovery_probe_failure).with(config, error)

        record_recovery_probe_failure
      end
    end

    context "when data_store fails" do
      it "notifies and fails over" do
        expect(error_notifier).to receive(:call).with(error)
        expect(failover_data_store).to receive(:record_recovery_probe_failure).with(config, error)
        expect(data_store).to receive(:record_recovery_probe_failure).with(config, error) { raise error }

        record_recovery_probe_failure
      end
    end
  end

  describe "#record_recovery_probe_success" do
    subject(:record_recovery_probe_success) { fail_safe.record_recovery_probe_success(config) }

    context "when data_store records recovery probe success" do
      it "delegates to data store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_recovery_probe_success).with(config)

        record_recovery_probe_success
      end
    end

    context "when data_store fails" do
      it "notifies and fallback" do
        expect(error_notifier).to receive(:call).with(error)
        expect(failover_data_store).to receive(:record_recovery_probe_success).with(config)
        expect(data_store).to receive(:record_recovery_probe_success).with(config) { raise error }

        record_recovery_probe_success
      end
    end
  end

  describe "#set_state" do
    subject { fail_safe.set_state(config, state) }
    let(:state) { Stoplight::State::LOCKED_GREEN }

    context "when data_store sets state" do
      it "returns state from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:set_state).with(config, state).and_return(state)

        is_expected.to eq(state)
      end
    end

    context "when data_store fails" do
      it "returns UNLOCKED state" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:set_state).with(config, state) { raise error }

        is_expected.to eq(Stoplight::State::LOCKED_GREEN)
      end
    end
  end

  describe "#transition_to_color" do
    subject { fail_safe.transition_to_color(config, color) }

    let(:color) { Stoplight::Color::GREEN }

    context "when data_store does not fail" do
      let(:value) { rand }

      it "returns the value" do
        expect(error_notifier).not_to receive(:call)

        expect(data_store).to receive(:transition_to_color).with(config, color).and_return(value)
        is_expected.to eq(value)
      end
    end

    context "when data_store fails" do
      it "returns false" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:transition_to_color).with(config, color).and_raise(error)

        is_expected.to eq(true)
      end
    end
  end
end

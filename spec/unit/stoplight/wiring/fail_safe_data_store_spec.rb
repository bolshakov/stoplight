# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::FailSafeDataStore do
  let(:fail_safe) { described_class.new(data_store:, error_notifier:, failover_data_store:) }
  let(:failover_data_store) { Stoplight::Infrastructure::DataStore::Memory.new }
  let(:data_store) { instance_double(Stoplight::Domain::DataStore) }
  let(:config) { Stoplight::Domain::Config.empty.with(name:, window_size: 4, cool_off_time: 60, threshold: 3) }
  let(:error_notifier) { instance_double(Proc) }
  let(:name) { SecureRandom.uuid }
  let(:error) { StandardError.new("Test error") }

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

  describe "#get_metadata" do
    subject(:get_metadata) { fail_safe.get_metadata(config) }

    context "when data_store returns all data" do
      let(:metadata) { Stoplight::Domain::Metadata.new(errors: 4) }

      it "returns all data from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:get_metadata).with(config).and_return(metadata)

        is_expected.to eq(metadata)
      end
    end

    context "when data_store fails" do
      it "returns empty list of all data" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:get_metadata).with(config) { raise error }

        is_expected.to eq(Stoplight::Domain::Metadata.new(current_time: get_metadata.current_time))
      end
    end
  end

  describe "#record_failure" do
    subject { fail_safe.record_failure(config, failure) }

    let(:failure) { Stoplight::Domain::Failure.new("class", "message", Time.new) }

    context "when data_store records failure" do
      it "returns total number of errors from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_failure).with(config, failure).and_return(4)

        is_expected.to eq(4)
      end
    end

    context "when data_store fails" do
      it "returns empty list of errors" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:record_failure).with(config, failure) { raise error }

        is_expected.to be_kind_of(Stoplight::Domain::Metadata)
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
    subject { fail_safe.record_recovery_probe_failure(config, failure) }

    let(:failure) { Stoplight::Domain::Failure.new("class", "message", Time.new) }

    context "when data_store records recovery probe failure" do
      let(:metadata) { Stoplight::Domain::Metadata.new(errors: 42, current_time: Time.now) }

      it "returns metadata from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure).and_return(metadata)

        is_expected.to eq(metadata)
      end
    end

    context "when data_store fails" do
      it "returns empty metadata" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:record_recovery_probe_failure).with(config, failure) { raise error }

        is_expected.to be_kind_of(Stoplight::Domain::Metadata)
      end
    end
  end

  describe "#record_recovery_probe_success" do
    subject { fail_safe.record_recovery_probe_success(config) }

    context "when data_store records recovery probe success" do
      let(:metadata) { Stoplight::Domain::Metadata.new(errors: 42, current_time: Time.now) }

      it "returns metadata from data_store" do
        expect(error_notifier).not_to receive(:call)
        expect(data_store).to receive(:record_recovery_probe_success).with(config).and_return(metadata)

        is_expected.to eq(metadata)
      end
    end

    context "when data_store fails" do
      it "returns empty metadata" do
        expect(error_notifier).to receive(:call).with(error)
        expect(data_store).to receive(:record_recovery_probe_success).with(config) { raise error }

        is_expected.to be_kind_of(Stoplight::Domain::Metadata)
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

  describe ".wrap" do
    subject { described_class.wrap(data_store:, error_notifier:) }

    context "when data_store is a Memory instance" do
      let(:data_store) { Stoplight::DataStore::Memory.new }

      it "returns the same data_store instance" do
        is_expected.to be(data_store)
      end
    end

    context "when data_store is a FailSafe instance with the same error_notifier" do
      let(:data_store) do
        described_class.new(
          data_store: Stoplight::DataStore::Memory.new,
          error_notifier:
        )
      end

      it "returns the same data_store instance" do
        is_expected.to be(data_store)
      end
    end

    context "when data_store is a FailSafe instance with a different error_notifier" do
      let(:underlying_data_store) { Stoplight::DataStore::Memory.new }
      let(:underlying_error_notifier) { ->(error) { warn error } }

      let(:data_store) do
        described_class.new(
          data_store: underlying_data_store,
          error_notifier: underlying_error_notifier
        )
      end

      it "returns a new FailSafe instance wrapping the data_store" do
        is_expected.to be_a(described_class)
        is_expected.to have_attributes(
          data_store: underlying_data_store,
          error_notifier: error_notifier
        )
      end
    end

    context "when data_store is another type" do
      let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

      it "returns a new FailSafe instance wrapping the data_store" do
        is_expected.to be_a(described_class)
        is_expected.to have_attributes(data_store:, error_notifier:)
      end
    end
  end

  describe "faulty data store" do
    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

    it "when primary store fails" do
      # Prepare: move internal circuit breaker into the red state
      allow(data_store).to receive(:names).and_raise(Redis::TimeoutError)
      config.threshold.times do
        expect { fail_safe.names }.not_to raise_error
      end

      # Verify: now the fallback data store is used
      RSpec::Mocks.space.proxy_for(data_store).reset
      allow(data_store).to receive(:names)
      allow(data_store).to receive(:record_success)

      fail_safe.record_success(config)
      expect(fail_safe.names).to include(config.name)

      expect(data_store).not_to have_received(:record_success), "expected to use fallback data store without trying primary"
      expect(data_store).not_to have_received(:names), "expected to use fallback data store without trying primary"

      # After cool_off_time, the primary data store is tried again
      Timecop.travel(Time.now + config.cool_off_time) do
        expect(data_store).to receive(:names).and_return(["recovered"])

        expect(fail_safe.names).to eq(["recovered"])
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::DataStore::FailSafe do
  let(:fail_safe) { described_class.new(data_store) }
  let(:data_store) { instance_double(Stoplight::DataStore::Base) }
  let(:error_notifier) { instance_double(Proc) }
  let(:config) { instance_double(Stoplight::Light::Config, error_notifier:) }
  let(:error) { StandardError.new("Test error") }

  it_behaves_like "Stoplight::DataStore::Base"

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

        is_expected.to eq([])
      end
    end
  end

  describe "#get_metadata" do
    subject { fail_safe.get_metadata(config) }

    context "when data_store returns all data" do
      let(:metadata) do
        Stoplight::Metadata.new.with(errors: 4)
      end

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

        is_expected.to eq(Stoplight::Metadata.new)
      end
    end
  end

  describe "#record_failure" do
    subject { fail_safe.record_failure(config, failure) }

    let(:failure) { Stoplight::Failure.new("class", "message", Time.new) }

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

        is_expected.to eq(nil)
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

        is_expected.to eq(Stoplight::State::UNLOCKED)
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

        is_expected.to eq(false)
      end
    end
  end

  describe ".wrap" do
    subject { described_class.wrap(data_store) }

    context "when data_store is a Memory instance" do
      let(:data_store) { Stoplight::DataStore::Memory.new }

      it "returns the same data_store instance" do
        is_expected.to be(data_store)
      end
    end

    context "when data_store is a FailSafe instance" do
      let(:data_store) { described_class.new(Stoplight::DataStore::Memory.new) }

      it "returns the same data_store instance" do
        is_expected.to be(data_store)
      end
    end

    context "when data_store is another type" do
      let(:data_store) { instance_double(Stoplight::DataStore::Base) }

      it "returns a new FailSafe instance wrapping the data_store" do
        is_expected.to be_a(described_class)
        expect(subject.instance_variable_get(:@data_store)).to eq(data_store)
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::Config do
  let(:config) { described_class.new(**settings) }

  let(:settings) do
    {
      name:,
      cool_off_time:,
      data_store:,
      error_notifier:,
      notifiers:,
      threshold:,
      window_size:,
      tracked_errors:,
      skipped_errors:
    }
  end

  let(:name) { "foobar" }
  let(:cool_off_time) { Stoplight::Default::COOL_OFF_TIME }
  let(:data_store) { Stoplight::Default::DATA_STORE }
  let(:error_notifier) { Stoplight::Default::ERROR_NOTIFIER }
  let(:notifiers) { Stoplight::Default::NOTIFIERS }
  let(:threshold) { Stoplight::Default::THRESHOLD }
  let(:window_size) { Stoplight::Default::WINDOW_SIZE }
  let(:tracked_errors) { Stoplight::Default::TRACKED_ERRORS }
  let(:skipped_errors) { Stoplight::Default::SKIPPED_ERRORS }

  context "with default settings" do
    subject(:config) { described_class.new(name:) }

    it "returns the default values" do
      is_expected.to have_attributes(
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        data_store: Stoplight::Default::DATA_STORE,
        error_notifier: Stoplight::Default::ERROR_NOTIFIER,
        notifiers: Stoplight::Default::NOTIFIERS,
        threshold: Stoplight::Default::THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        tracked_errors: Stoplight::Default::TRACKED_ERRORS,
        skipped_errors: Stoplight::Default::SKIPPED_ERRORS
      )
    end
  end

  describe "#cool_off_time" do
    subject { config.cool_off_time }

    context "when set to a float number" do
      let(:cool_off_time) { 66.4 }

      it "returns the correct value" do
        is_expected.to eq(cool_off_time)
      end
    end

    context "when set to an integer number" do
      let(:cool_off_time) { 66 }

      it "returns the correct value casted to Float" do
        is_expected.to eq(66.0)
      end
    end
  end

  describe "#data_store" do
    subject { config.data_store }

    let(:data_store) { Stoplight::DataStore::Memory.new }

    it "returns the same value" do
      is_expected.to be(data_store)
    end
  end

  describe "#error_notifier" do
    subject { config.error_notifier }

    let(:error_notifier) { ->(error) { warn error } }

    it "returns the same value" do
      is_expected.to be(error_notifier)
    end
  end

  describe "#notifiers" do
    subject { config.notifiers }

    let(:notifiers) { [Stoplight::Notifier::IO.new($stderr)] }

    it "returns the same value" do
      is_expected.to contain_exactly(*notifiers)
    end
  end

  describe "#threshold" do
    subject { config.threshold }

    let(:threshold) { 5 }

    it "returns the same value" do
      is_expected.to eq(threshold)
    end
  end

  describe "#window_size" do
    subject { config.window_size }

    let(:window_size) { 10 }

    it "returns the same value" do
      is_expected.to eq(window_size)
    end
  end

  describe "#tracked_errors" do
    subject { config.tracked_errors }

    let(:tracked_errors) { [StandardError] }

    it "returns the same value" do
      is_expected.to contain_exactly(*tracked_errors)
    end
  end

  describe "#skipped_errors" do
    subject { config.skipped_errors }

    let(:error_class) { Class.new(StandardError) }
    let(:skipped_errors) { [error_class] }

    it "returns the same value" do
      is_expected.to contain_exactly(*skipped_errors, *Stoplight::Default::SKIPPED_ERRORS)
    end
  end

  describe "#name" do
    subject { config.name }

    let(:name) { "foobar" }

    it "returns the same value" do
      is_expected.to eq(name)
    end
  end

  describe "#with" do
    subject { config.with(**new_settings) }

    context "when all settings are updated" do
      let(:new_settings) do
        {
          name: "bar",
          cool_off_time: 10,
          data_store: Stoplight::DataStore::Memory.new,
          error_notifier: ->(error) { warn error },
          notifiers: [Stoplight::Notifier::IO.new($stderr)],
          threshold: 5,
          window_size: 10,
          tracked_errors: [StandardError],
          skipped_errors: [KeyError]
        }
      end

      it "returns a new config with the updated settings" do
        is_expected.to be_a(described_class)
        is_expected.to have_attributes(**new_settings.merge(skipped_errors: [KeyError, *Stoplight::Default::SKIPPED_ERRORS]))
      end
    end

    context "when some settings are not updated" do
      let(:new_settings) do
        {
          name: "bar",
          cool_off_time: 10,
          data_store: Stoplight::DataStore::Memory.new,
          error_notifier: ->(error) { warn error },
          notifiers: [Stoplight::Notifier::IO.new($stderr)]
        }
      end

      it "returns a new config with the updated settings" do
        is_expected.to be_a(described_class)
        is_expected.to have_attributes(**settings.merge(new_settings))
      end
    end
  end
end

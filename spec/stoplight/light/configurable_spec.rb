# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Light::Configurable do
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:light) { Stoplight::Light.new(config) }

  let(:config) do
    Stoplight::Light::Config.new(
      name: name,
      data_store: Stoplight::Default::DATA_STORE,
      notifiers: Stoplight::Default::NOTIFIERS,
      error_notifier: Stoplight::Default::ERROR_NOTIFIER,
      cool_off_time: Stoplight::Default::COOL_OFF_TIME,
      threshold: Stoplight::Default::THRESHOLD,
      window_size: Stoplight::Default::WINDOW_SIZE
    )
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

    subject(:with_combined_settings) { light.with(**settings) }

    it "applies all settings correctly" do
      expect(with_combined_settings.config).to have_attributes(**settings)
    end
  end

  shared_examples "configurable attribute" do |attribute|
    subject(:with_attribute) do
      light.__send__(:"with_#{attribute}", __send__(attribute))
    end

    it "configures #{attribute}" do
      expect(with_attribute.config.__send__(attribute)).to eq(__send__(attribute))
    end
  end

  describe "#with_data_store" do
    let(:data_store) { Stoplight::DataStore::Memory.new }

    include_examples "configurable attribute", :data_store
  end

  describe "#cool_off_time" do
    let(:cool_off_time) { 1_000 }

    include_examples "configurable attribute", :cool_off_time
  end

  describe "#with_threshold" do
    let(:threshold) { 1_000 }

    include_examples "configurable attribute", :threshold
  end

  describe "#with_window_size" do
    let(:window_size) { 1_000 }

    include_examples "configurable attribute", :window_size
  end

  describe "#with_notifiers" do
    let(:notifiers) { [Stoplight::Notifier::FailSafe.wrap(Stoplight::Notifier::IO.new($stderr))] }

    include_examples "configurable attribute", :notifiers
  end

  describe "#with_error_notifier" do
    let(:error_notifier) { ->(x) { x } }

    subject(:with_attribute) do
      light.with_error_notifier(&error_notifier)
    end

    it "configures error notifier" do
      expect(with_attribute.config.error_notifier).to eq(error_notifier)
    end
  end

  describe "#with_tracked_errors" do
    let(:tracked_errors) { [RuntimeError, KeyError] }

    subject(:with_attribute) do
      light.with_tracked_errors(*tracked_errors)
    end

    it "configures tracked errors" do
      expect(with_attribute.config.tracked_errors).to contain_exactly(*tracked_errors)
    end
  end

  describe "#with_skipped_errors" do
    let(:skipped_errors) { [RuntimeError, KeyError] }

    subject(:with_attribute) do
      light.with_skipped_errors(*skipped_errors)
    end

    it "configures skipped errors" do
      expect(with_attribute.config.skipped_errors).to contain_exactly(*skipped_errors,
        *Stoplight::Default::SKIPPED_ERRORS)
    end
  end
end

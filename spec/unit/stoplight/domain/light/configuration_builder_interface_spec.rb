# frozen_string_literal: true

RSpec.describe Stoplight::Domain::Light::ConfigurationBuilderInterface do
  let(:name) { ("a".."z").to_a.shuffle.join }
  let(:light) do
    Stoplight::Domain::Light.new(
      nil,
      green_run_strategy: nil,
      yellow_run_strategy: nil,
      red_run_strategy: nil,
      data_store: nil,
      factory:
    )
  end
  let(:factory) { instance_double(Stoplight::Domain::LightFactory) }

  shared_examples "configurable attribute" do |attribute|
    subject(:light_with_attribute) do
      if as_list
        light.__send__(:"with_#{attribute}", *attribute_value)
      else
        light.__send__(:"with_#{attribute}", attribute_value)
      end
    end

    let(:attribute_value) { __send__(attribute) }
    let(:as_list) { false }

    it "configures #{attribute}" do
      expect(factory).to receive(:build_with).with(attribute => attribute_value)

      light_with_attribute
    end
  end

  describe "#with_data_store" do
    let(:data_store) { instance_double(Stoplight::Domain::DataStore) }

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
    let(:notifiers) { [instance_double(Stoplight::Domain::StateTransitionNotifier)] }

    include_examples "configurable attribute", :notifiers
  end

  describe "#with_error_notifier" do
    let(:error_notifier) { ->(x) { x } }

    subject(:light_with_attribute) do
      light.with_error_notifier(&error_notifier)
    end

    it "configures error notifier" do
      expect(factory).to receive(:build_with).with(error_notifier: error_notifier)

      light_with_attribute
    end
  end

  describe "#with_tracked_errors" do
    let(:tracked_errors) { [RuntimeError, KeyError] }

    include_examples "configurable attribute", :tracked_errors do
      let(:as_list) { true }
    end
  end

  describe "#with_skipped_errors" do
    let(:skipped_errors) { [RuntimeError, KeyError] }

    include_examples "configurable attribute", :skipped_errors do
      let(:as_list) { true }
    end
  end
end

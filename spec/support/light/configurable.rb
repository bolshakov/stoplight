# frozen_string_literal: true

RSpec.shared_examples Stoplight::Light::Configurable do
  let(:config) do
    Stoplight::Light::Config.new(
      name: name,
      data_store: Stoplight.default_data_store,
      notifiers: Stoplight.default_notifiers,
      error_notifier: Stoplight.default_error_notifier,
      cool_off_time: Stoplight::Default::COOL_OFF_TIME,
      threshold: Stoplight::Default::THRESHOLD,
      window_size: Stoplight::Default::WINDOW_SIZE
    )
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
    let(:data_store) { instance_double(Stoplight::DataStore::Redis) }

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
    let(:notifiers) { 1_000 }

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

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Config::ConfigProvider do
  subject(:config_provider) do
    described_class.new(
      user_default_config:,
      library_default_config:
    )
  end

  let(:library_default_config) { Stoplight::Config::LibraryDefaultConfig.new }
  let(:user_default_config) { Stoplight::Config::UserDefaultConfig.new }

  describe "#provide" do
    let(:config) { config_provider.provide(:test_light, **settings_overrides) }

    context "when settings_overrides includes name" do
      let(:settings_overrides) { {name: "test_light"} }

      it "raises configuration error" do
        expect do
          config
        end.to raise_error(Stoplight::Error::ConfigurationError, /The \+name\+ setting cannot be overridden in the configuration/)
      end
    end

    context "with user default configuration" do
      let(:user_default_config) do
        Stoplight::Config::UserDefaultConfig.new.tap do |config|
          config.data_store = data_store
          config.error_notifier = error_notifier
          config.notifiers += notifiers
          config.cool_off_time = cool_off_time
          config.threshold = threshold
          config.window_size = window_size
          config.tracked_errors = tracked_errors
          config.skipped_errors = skipped_errors
        end
      end
      let(:data_store) { Stoplight::DataStore::Memory.new }
      let(:error_notifier) { ->(error) { puts "Error: #{error}" } }
      let(:notifiers) { [Stoplight::Notifier::IO.new($stdout)] }
      let(:cool_off_time) { 10 }
      let(:threshold) { 5 }
      let(:window_size) { 20 }
      let(:tracked_errors) { [StandardError] }
      let(:skipped_errors) { [RuntimeError] }

      context "without settings overrides" do
        let(:settings_overrides) { {} }

        it "returns a configuration from user default settings" do
          expect(config).to have_attributes(
            data_store: data_store,
            error_notifier: error_notifier,
            notifiers: contain_exactly(
              *[
                *Stoplight::Default::NOTIFIERS,
                *notifiers
              ].map { |x| Stoplight::Notifier::FailSafe.wrap(x) }
            ),
            cool_off_time: cool_off_time,
            threshold: threshold,
            window_size: window_size,
            tracked_errors: tracked_errors,
            skipped_errors: include(*skipped_errors)
          )
        end
      end

      context "with settings overrides" do
        let(:overridden_data_store) { instance_double(Stoplight::DataStore::Redis) }
        let(:settings_overrides) do
          {
            data_store: overridden_data_store
          }
        end

        it "returns a configuration from user default settings with provided overrides" do
          expect(config).to have_attributes(
            data_store: Stoplight::DataStore::FailSafe.new(overridden_data_store),
            error_notifier: error_notifier,
            notifiers: contain_exactly(
              *[
                *Stoplight::Default::NOTIFIERS,
                *notifiers
              ].map { |x| Stoplight::Notifier::FailSafe.wrap(x) }
            ),
            cool_off_time: cool_off_time,
            threshold: threshold,
            window_size: window_size,
            tracked_errors: tracked_errors,
            skipped_errors: include(*skipped_errors)
          )
        end
      end
    end

    describe "data_store" do
      subject { config_provider.provide("name", data_store:).data_store }

      let(:data_store) { instance_double(Stoplight::DataStore::Base) }

      it "wraps data store with fail safe" do
        is_expected.to eq(Stoplight::DataStore::FailSafe.new(data_store))
      end
    end

    describe "notifiers" do
      subject { config_provider.provide("name", notifiers: [notifier]).notifiers }

      let(:notifier) { instance_double(Stoplight::Notifier::Base) }

      it "wraps notifiers with fail safe" do
        is_expected.to contain_exactly(Stoplight::Notifier::FailSafe.new(notifier))
      end
    end

    describe "tracked_errors" do
      subject { config_provider.provide("name", tracked_errors: tracked_error).tracked_errors }

      let(:tracked_error) { KeyError }

      it "wraps tracked errors into an array" do
        is_expected.to contain_exactly(KeyError)
      end
    end

    describe "skipped_errors" do
      subject { config_provider.provide("name", skipped_errors: skipped_error).skipped_errors }

      let(:skipped_error) { KeyError }

      it "wraps skipped errors into an array" do
        is_expected.to contain_exactly(KeyError)
      end
    end

    describe "cool_off_time" do
      subject { config_provider.provide("name", cool_off_time:).cool_off_time }

      let(:cool_off_time) { 60.0 }

      it "converts to integer" do
        is_expected.to be(60)
      end
    end
  end
end

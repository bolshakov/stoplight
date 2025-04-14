# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stoplight::Config::ConfigProvider do
  subject(:config_provider) do
    described_class.new(
      user_default_config:,
      library_default_config:,
      legacy_config:
    )
  end

  let(:library_default_config) { Stoplight::Config::LibraryDefaultConfig.new }
  let(:user_default_config) { Stoplight::Config::UserDefaultConfig.new }
  let(:legacy_config) { Stoplight::Config::LegacyConfig.new }

  context "with user default configuration and legacy configuration are not empty" do
    let(:user_default_config) do
      Stoplight::Config::UserDefaultConfig.new.tap do |config|
        config.cool_off_time = 10
      end
    end
    let(:legacy_config) do
      Stoplight::Config::LegacyConfig.new(
        error_notifier: ->(error) { puts "Error: #{error}" }
      )
    end

    it "raises configuration error" do
      expect do
        config_provider
      end.to raise_error(Stoplight::Error::ConfigurationError, /Configuration conflict detected!/)
    end
  end

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
      let(:cool_off_time) { 10.0 }
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
            notifiers: contain_exactly(*Stoplight::Default::NOTIFIERS, *notifiers),
            cool_off_time: cool_off_time,
            threshold: threshold,
            window_size: window_size,
            tracked_errors: tracked_errors,
            skipped_errors: include(*skipped_errors)
          )
        end
      end

      context "with settings overrides" do
        let(:redis) { instance_double(Redis) }
        let(:overridden_data_store) { Stoplight::DataStore::Redis.new(redis) }
        let(:settings_overrides) do
          {
            data_store: overridden_data_store
          }
        end

        it "returns a configuration from user default settings with provided overrides" do
          expect(config).to have_attributes(
            data_store: overridden_data_store,
            error_notifier: error_notifier,
            notifiers: contain_exactly(*Stoplight::Default::NOTIFIERS, *notifiers),
            cool_off_time: cool_off_time,
            threshold: threshold,
            window_size: window_size,
            tracked_errors: tracked_errors,
            skipped_errors: include(*skipped_errors)
          )
        end
      end
    end

    context "with legacy configuration" do
      let(:user_default_config) do
        Stoplight::Config::LegacyConfig.new(
          data_store: data_store,
          error_notifier: error_notifier,
          notifiers: notifiers
        )
      end
      let(:data_store) { Stoplight::DataStore::Memory.new }
      let(:error_notifier) { ->(error) { puts "Error: #{error}" } }
      let(:notifiers) { [Stoplight::Notifier::IO.new($stdout)] }

      context "without settings overrides" do
        let(:settings_overrides) { {} }

        it "returns a configuration from legacy settings" do
          expect(config).to have_attributes(
            cool_off_time: Stoplight::Default::COOL_OFF_TIME,
            threshold: Stoplight::Default::THRESHOLD,
            window_size: Stoplight::Default::WINDOW_SIZE,
            tracked_errors: Stoplight::Default::TRACKED_ERRORS,
            skipped_errors: Stoplight::Default::SKIPPED_ERRORS,
            data_store: data_store,
            error_notifier: error_notifier,
            notifiers: contain_exactly(*notifiers)
          )
        end
      end

      context "with settings overrides" do
        let(:redis) { instance_double(Redis) }
        let(:overridden_data_store) { Stoplight::DataStore::Redis.new(redis) }
        let(:settings_overrides) do
          {
            data_store: overridden_data_store
          }
        end

        it "returns a configuration from legacy settings with provided overrides" do
          expect(config).to have_attributes(
            cool_off_time: Stoplight::Default::COOL_OFF_TIME,
            threshold: Stoplight::Default::THRESHOLD,
            window_size: Stoplight::Default::WINDOW_SIZE,
            tracked_errors: Stoplight::Default::TRACKED_ERRORS,
            skipped_errors: Stoplight::Default::SKIPPED_ERRORS,
            data_store: overridden_data_store,
            error_notifier: error_notifier,
            notifiers: contain_exactly(*notifiers)
          )
        end
      end
    end
  end
end

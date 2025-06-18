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

    describe "traffic_control symbol and hash support" do
      it "accepts :error_rate symbol in explicit settings" do
        config = config_provider.provide("api", traffic_control: :error_rate)
        expect(config.traffic_control).to be_a(Stoplight::TrafficControl::ErrorRate)
      end

      it "accepts :consecutive_failures symbol in explicit settings" do
        config = config_provider.provide("api", traffic_control: :consecutive_failures)
        expect(config.traffic_control).to be_a(Stoplight::TrafficControl::ConsecutiveFailures)
      end

      it "accepts hash for error_rate with options" do
        config = config_provider.provide("api", traffic_control: {error_rate: {min_requests: 42}})
        tc = config.traffic_control
        expect(tc).to be_a(Stoplight::TrafficControl::ErrorRate)
        expect(tc.instance_variable_get(:@min_sample_size)).to eq(42)
      end

      it "accepts hash for consecutive_failures with options" do
        config = config_provider.provide("api", traffic_control: {consecutive_failures: {}})
        tc = config.traffic_control
        expect(tc).to be_a(Stoplight::TrafficControl::ConsecutiveFailures)
      end

      it "raises for unknown hash key" do
        expect {
          config_provider.provide("api", traffic_control: {unknown: {}})
        }.to raise_error(ArgumentError)
      end

      it "uses user default config for traffic_control if not overridden" do
        user_default_config.traffic_control = :error_rate
        config = config_provider.provide("api")
        expect(config.traffic_control).to be_a(Stoplight::TrafficControl::ErrorRate)
      end

      context "when neither user nor library default config sets traffic_control" do
        let(:library_default_config) do
          # Return a hash without :traffic_control
          double(to_h: {cool_off_time: 1, data_store: Stoplight::Default::DATA_STORE, error_notifier: Stoplight::Default::ERROR_NOTIFIER, notifiers: Stoplight::Default::NOTIFIERS, threshold: 1, window_size: 1, tracked_errors: [StandardError], skipped_errors: [], traffic_recovery: Stoplight::Default::TRAFFIC_RECOVERY})
        end
        let(:user_default_config) do
          # Return an empty hash
          double(to_h: {})
        end
        let(:settings_overrides) { {} }

        it "falls back to Default::TRAFFIC_CONTROL" do
          config = config_provider.provide(:test_light)
          expect(config.traffic_control).to eq(Stoplight::Default::TRAFFIC_CONTROL)
        end
      end

      context "when default_settings has :traffic_control key with nil value" do
        let(:library_default_config) do
          double(to_h: {cool_off_time: 1, data_store: Stoplight::Default::DATA_STORE, error_notifier: Stoplight::Default::ERROR_NOTIFIER, notifiers: Stoplight::Default::NOTIFIERS, threshold: 1, window_size: 1, tracked_errors: [StandardError], skipped_errors: [], traffic_recovery: Stoplight::Default::TRAFFIC_RECOVERY, traffic_control: nil})
        end
        let(:user_default_config) { double(to_h: {}) }
        let(:settings_overrides) { {} }

        it "returns nil for traffic_control" do
          config = config_provider.provide(:test_light)
          expect(config.traffic_control).to be_nil
        end
      end
    end
  end
end

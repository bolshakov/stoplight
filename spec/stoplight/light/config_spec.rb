# frozen_string_literal: true

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
      skipped_errors:,
      traffic_control:,
      traffic_recovery:
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
  let(:traffic_control) { Stoplight::Default::TRAFFIC_CONTROL }
  let(:traffic_recovery) { Stoplight::Default::TRAFFIC_RECOVERY }

  describe "#track_error?" do
    subject { config.track_error?(error) }

    context "when the error is in skipped_errors" do
      let(:error) { skipped_errors.first.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be false }
    end

    context "when the error is in tracked_errors but not in skipped_errors" do
      let(:error) { tracked_errors.first.new }
      let(:skipped_errors) { [RuntimeError] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be true }
    end

    context "when the error is in neither tracked_errors nor skipped_errors" do
      let(:error) { RuntimeError.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [ArgumentError] }

      it { is_expected.to be false }
    end

    context "when skipped_errors is empty" do
      let(:error) { StandardError.new }
      let(:skipped_errors) { [] }
      let(:tracked_errors) { [StandardError] }

      it { is_expected.to be true }
    end

    context "when tracked_errors is empty" do
      let(:error) { StandardError.new }
      let(:skipped_errors) { [StandardError] }
      let(:tracked_errors) { [] }

      it { is_expected.to be false }
    end
  end

  describe "#with" do
    let(:config) { default_config.with(name: :test_light, **settings_overrides) }

    let(:default_config) { Stoplight::Config::LibraryDefaultConfig.with(**user_default_config.to_h) }
    let(:user_default_config) { Stoplight::Config::UserDefaultConfig.new }

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
      subject { Stoplight.default_config.with(name: "name", data_store:).data_store }

      let(:data_store) { instance_double(Stoplight::DataStore::Base) }

      it "wraps data store with fail safe" do
        is_expected.to eq(Stoplight::DataStore::FailSafe.new(data_store))
      end
    end

    describe "notifiers" do
      subject { Stoplight.default_config.with(name: "name", notifiers: [notifier]).notifiers }

      let(:notifier) { instance_double(Stoplight::Notifier::Base) }

      it "wraps notifiers with fail safe" do
        is_expected.to contain_exactly(Stoplight::Notifier::FailSafe.new(notifier))
      end
    end

    describe "tracked_errors" do
      subject { Stoplight.default_config.with(name: "name", tracked_errors: tracked_error).tracked_errors }

      let(:tracked_error) { KeyError }

      it "wraps tracked errors into an array" do
        is_expected.to contain_exactly(KeyError)
      end
    end

    describe "skipped_errors" do
      subject { Stoplight.default_config.with(name: "name", skipped_errors: skipped_error).skipped_errors }

      let(:skipped_error) { KeyError }

      it "wraps skipped errors into an array" do
        is_expected.to contain_exactly(KeyError)
      end
    end

    describe "cool_off_time" do
      subject { Stoplight.default_config.with(name: "name", cool_off_time:).cool_off_time }

      let(:cool_off_time) { 60.0 }

      it "converts to integer" do
        is_expected.to be(60)
      end
    end

    describe "traffic_control" do
      subject(:traffic_control_out) do
        Stoplight.default_config.with(
          name: "name",
          traffic_control:,
          window_size: 300,
          threshold:
        ).traffic_control
      end

      let(:threshold) { 50 }

      context "when an instance of TrafficControl::Base" do
        let(:traffic_control) { Stoplight::TrafficControl::ConsecutiveErrors.new }

        it "returns the same traffic control object" do
          is_expected.to eq(traffic_control)
        end
      end

      context "when :consecutive_errors" do
        let(:traffic_control) { :consecutive_errors }

        it "returns an instance of Stoplight::TrafficControl::ConsecutiveErrors" do
          is_expected.to eq(Stoplight::TrafficControl::ConsecutiveErrors.new)
        end
      end

      context "when :error_rate" do
        let(:traffic_control) { :error_rate }
        let(:threshold) { 0.5 }

        it "returns an instance of Stoplight::TrafficControl::ErrorRate" do
          is_expected.to eq(Stoplight::TrafficControl::ErrorRate.new)
        end
      end

      context "when :error_rate with options" do
        let(:traffic_control) { {error_rate: {min_requests: 11}} }
        let(:threshold) { 0.5 }

        it "returns an instance of Stoplight::TrafficControl::ErrorRate with min_requests" do
          is_expected.to eq(Stoplight::TrafficControl::ErrorRate.new(min_requests: 11))
        end
      end

      context "when unsupported option" do
        let(:traffic_control) { :latency }

        it "raises an error" do
          expect { traffic_control_out }.to raise_error(Stoplight::Error::ConfigurationError)
        end
      end

      context "when traffic control is not compatible with the config" do
        let(:traffic_control) { {error_rate: {min_requests: 11}} }
        let(:threshold) { 5 } # must be 0..1

        it "raises a configuration errors" do
          expect { traffic_control_out }.to raise_error(
            Stoplight::Error::ConfigurationError,
            "Stoplight::TrafficControl::ErrorRate strategy is incompatible with the Stoplight configuration: " \
              "`threshold` should be between 0 and 1"
          )
        end
      end
    end
  end
end

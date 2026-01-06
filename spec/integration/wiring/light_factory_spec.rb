# frozen_string_literal: true

RSpec.describe Stoplight::Wiring::LightFactory do
  let(:settings) { Stoplight::Wiring::Settings.empty.extend_with(name: SecureRandom.uuid) }
  let(:factory) { described_class.new(settings:) }
  let(:light) { factory.build }

  describe "transformations" do
    describe "tracked_errors" do
      subject(:tracked_errors) { light.config.tracked_errors }

      let(:settings) { super().extend_with(tracked_errors: [Timeout::Error]) }

      it "normalizes tracked_errors to array" do
        expect(tracked_errors).to eq([Timeout::Error])
      end
    end

    describe "skipped_errors" do
      subject(:skipped_errors) { light.config.skipped_errors }

      let(:settings) { super().extend_with(skipped_errors: [Timeout::Error]) }

      it "normalizes skipped_errors to array" do
        expect(skipped_errors).to eq([Timeout::Error])
      end
    end

    describe "cool_off_time" do
      subject(:cool_off_time) { light.config.cool_off_time }

      let(:settings) { super().extend_with(cool_off_time: 120) }

      it "converts cool_off_time to integer" do
        expect(cool_off_time).to eq(120)
      end
    end

    describe "traffic_recovery" do
      subject(:traffic_recovery_out) do
        light
          .__send__(:yellow_run_strategy)
          .__send__(:request_tracker)
          .__send__(:traffic_recovery)
      end

      let(:settings) { super().extend_with(traffic_recovery: traffic_recovery_in, recovery_threshold: 2) }

      context "when TrafficRecovery::ConsecutiveSuccesses" do
        let(:traffic_recovery_in) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }

        it "returns the same traffic recovery object" do
          expect(traffic_recovery_out).to eq(traffic_recovery_in)
        end
      end

      context "when :consecutive_successes" do
        let(:traffic_recovery_in) { :consecutive_successes }

        it "returns an instance of Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses" do
          is_expected.to eq(Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new)
        end
      end

      context "when unexpected strategy provided" do
        let(:traffic_recovery_in) { 42 }

        it "raises configuration error" do
          expect do
            traffic_recovery_out
          end.to raise_error(Stoplight::Error::ConfigurationError, <<~ERROR)
            unsupported traffic_recovery strategy provided (`42`). Supported options:
              * :consecutive_successes
          ERROR
        end
      end
    end

    describe "traffic_control" do
      subject(:traffic_control_out) do
        light
          .__send__(:green_run_strategy)
          .__send__(:request_tracker)
          .__send__(:traffic_control)
      end

      let(:settings) { super().extend_with(traffic_control: traffic_control_in, **config) }

      context "when TrafficControl::ConsecutiveErrors" do
        let(:traffic_control_in) { Stoplight::Domain::TrafficControl::ConsecutiveErrors.new }
        let(:config) { {threshold: 5} }

        it "returns the same traffic control object" do
          expect(traffic_control_out).to eq(traffic_control_in)
        end
      end

      context "when :consecutive_errors" do
        let(:traffic_control_in) { :consecutive_errors }
        let(:config) { {threshold: 5} }

        it "returns an instance of Stoplight::Domain::TrafficControl::ConsecutiveErrors" do
          expect(traffic_control_out).to eq(Stoplight::Domain::TrafficControl::ConsecutiveErrors.new)
        end
      end

      context "when :error_rate" do
        let(:traffic_control_in) { :error_rate }
        let(:config) { {threshold: 0.5, window_size: 60} }

        it "returns an instance of Stoplight::Domain::TrafficControl::ErrorRate" do
          expect(traffic_control_out).to eq(Stoplight::Domain::TrafficControl::ErrorRate.new)
        end
      end

      context "when :error_rate with options" do
        let(:traffic_control_in) { {error_rate: {min_requests: 11}} }
        let(:config) { {threshold: 0.5, window_size: 60} }

        it "returns an instance of Stoplight::Domain::TrafficControl::ErrorRate with min_requests" do
          expect(traffic_control_out).to eq(Stoplight::Domain::TrafficControl::ErrorRate.new(min_requests: 11))
        end
      end

      context "when unsupported option" do
        let(:traffic_control_in) { :latency }
        let(:config) { {} }

        it "raises an error" do
          expect { traffic_control_out }.to raise_error(Stoplight::Error::ConfigurationError)
        end
      end
    end
  end

  describe "validation" do
    context "when traffic control is not compatible with the config" do
      let(:settings) { super().extend_with(traffic_control:, threshold: 4, window_size: 60) }
      let(:traffic_control) { Stoplight::Domain::TrafficControl::ErrorRate.new }

      it "raises a configuration errors" do
        expect { light }.to raise_error(
          Stoplight::Error::ConfigurationError,
          "Stoplight::Domain::TrafficControl::ErrorRate incompatible with config: " \
            "`threshold` should be between 0 and 1"
        )
      end
    end

    context "when traffic recovery is not compatible with the config" do
      let(:settings) { super().extend_with(traffic_recovery:, recovery_threshold: -1) }
      let(:traffic_recovery) { Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new }

      it "raises a configuration errors" do
        expect { light }.to raise_error(
          Stoplight::Error::ConfigurationError,
          "Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses incompatible with config: " \
            "`recovery_threshold` should be bigger than 0"
        )
      end
    end
  end
end

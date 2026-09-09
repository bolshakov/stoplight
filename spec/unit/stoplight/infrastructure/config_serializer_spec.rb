# frozen_string_literal: true

RSpec.describe Stoplight::Infrastructure::ConfigSerializer do
  describe ".call" do
    subject(:serialized) { described_class.call(config) }

    let(:config) do
      instance_double(
        Stoplight::Domain::Config,
        id: "fffffff",
        name: "Payment Gateway",
        cool_off_time: 60.0,
        threshold: 5,
        recovery_threshold: 1,
        window_size: 300,
        tracked_errors: [StandardError],
        skipped_errors: [ArgumentError],
        traffic_control: Stoplight::Domain::TrafficControl::ConsecutiveErrors.new,
        traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new
      )
    end

    it "includes the id" do
      expect(serialized["id"]).to eq("fffffff")
    end

    it "includes the name" do
      expect(serialized["name"]).to eq("Payment Gateway")
    end

    it "includes the cool_off_time" do
      expect(serialized["cool_off_time"]).to eq(60.0)
    end

    it "includes the threshold" do
      expect(serialized["threshold"]).to eq(5)
    end

    it "includes the recovery_threshold" do
      expect(serialized["recovery_threshold"]).to eq(1)
    end

    it "includes the window_size" do
      expect(serialized["window_size"]).to eq(300)
    end

    it "includes the tracked_errors as constant-name strings" do
      expect(serialized["tracked_errors"]).to eq(["StandardError"])
    end

    it "includes the skipped_errors as constant-name strings" do
      expect(serialized["skipped_errors"]).to eq(["ArgumentError"])
    end

    it "includes the traffic_control strategy" do
      expect(serialized["traffic_control"]).to eq({"strategy" => "consecutive_errors"})
    end

    it "includes the traffic_recovery strategy" do
      expect(serialized["traffic_recovery"]).to eq({"strategy" => "consecutive_successes"})
    end

    context "when traffic_control is error_rate" do
      let(:config) do
        instance_double(
          Stoplight::Domain::Config,
          id: "fffffff",
          name: "Payment Gateway",
          cool_off_time: 60.0,
          threshold: 5,
          recovery_threshold: 1,
          window_size: 300,
          tracked_errors: [StandardError],
          skipped_errors: [ArgumentError],
          traffic_control: Stoplight::Domain::TrafficControl::ErrorRate.new,
          traffic_recovery: Stoplight::Domain::TrafficRecovery::ConsecutiveSuccesses.new
        )
      end

      it "includes the error_rate strategy" do
        expect(serialized["traffic_control"]).to eq({"strategy" => "error_rate"})
      end
    end

    context "when traffic_control is unsupported" do
      let(:config) do
        instance_double(
          Stoplight::Domain::Config,
          id: "fffffff",
          name: "Payment Gateway",
          cool_off_time: 60.0,
          threshold: 5,
          recovery_threshold: 1,
          window_size: 300,
          tracked_errors: [StandardError],
          skipped_errors: [ArgumentError],
          traffic_control: Object.new
        )
      end

      it "raises TypeError" do
        expect { serialized }.to raise_error(TypeError)
      end
    end

    context "when traffic_recovery is unsupported" do
      let(:config) do
        instance_double(
          Stoplight::Domain::Config,
          id: "fffffff",
          name: "Payment Gateway",
          cool_off_time: 60.0,
          threshold: 5,
          recovery_threshold: 1,
          window_size: 300,
          tracked_errors: [StandardError],
          skipped_errors: [ArgumentError],
          traffic_control: Stoplight::Domain::TrafficControl::ConsecutiveErrors.new,
          traffic_recovery: Object.new
        )
      end

      it "raises TypeError" do
        expect { serialized }.to raise_error(TypeError)
      end
    end
  end
end

# frozen_string_literal: true

require "rantly/rspec_extensions"

RSpec.describe Stoplight::Wiring::LightConfigurationDsl do
  describe "#digest" do
    # Main property test: same params = same digest
    specify "produces same digest for identical parameters across all variations" do
      property_of {
        {
          name: string,
          cool_off_time: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          threshold: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          recovery_threshold: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          window_size: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          tracked_errors: choose(
            StandardError,
            [StandardError],
            [RuntimeError, ArgumentError],
            [],
            Stoplight::Types.undefined
          ),
          skipped_errors: choose(
            ArgumentError,
            [ArgumentError],
            [IOError, SystemCallError],
            [],
            Stoplight::Types.undefined
          ),
          traffic_control: choose(
            :consecutive_errors,
            :error_rate,
            Stoplight::Types.undefined
          ),
          traffic_recovery: choose(
            :consecutive_successes,
            Stoplight::Types.undefined
          )
        }
      }.check do |params|
        dsl1 = described_class.new(**params)
        dsl2 = described_class.new(**params)

        expect(dsl1.digest).to eq(dsl2.digest),
          "Expected same digest for identical params: #{params.inspect}"
      end
    end

    # Property: digest is stable
    specify "digest remains stable across multiple calls" do
      property_of {
        {
          name: string,
          cool_off_time: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          threshold: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          recovery_threshold: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          window_size: choose(integer.abs, float.abs, Stoplight::Types.undefined),
          tracked_errors: choose(
            StandardError,
            [StandardError],
            [RuntimeError, ArgumentError],
            [],
            Stoplight::Types.undefined
          ),
          skipped_errors: choose(
            ArgumentError,
            [ArgumentError],
            [IOError, SystemCallError],
            [],
            Stoplight::Types.undefined
          ),
          traffic_control: choose(
            :consecutive_errors,
            :error_rate,
            Stoplight::Types.undefined
          ),
          traffic_recovery: choose(
            :consecutive_successes,
            Stoplight::Types.undefined
          )
        }
      }.check do |params|
        dsl = described_class.new(**params)

        digest1 = dsl.digest
        digest2 = dsl.digest
        digest3 = dsl.digest

        expect(digest1).to eq(digest2)
        expect(digest2).to eq(digest3)
      end
    end

    # Property: normalization produces same digest
    specify "produces same digest for normalized values" do
      property_of {
        name = string
        error_class = choose(StandardError, RuntimeError, ArgumentError)

        [
          {name: name, tracked_errors: error_class},
          {name: name, tracked_errors: [error_class]}
        ]
      }.check do |params1, params2|
        dsl1 = described_class.new(**params1)
        dsl2 = described_class.new(**params2)

        expect(dsl1.digest).to eq(dsl2.digest)
      end
    end

    # Property: parameter order doesn't matter
    specify "produces same digest regardless of parameter order" do
      property_of {
        name = string
        cool_off_time = choose(integer.abs, float.abs, Stoplight::Types.undefined)
        threshold = choose(integer.abs, float.abs, Stoplight::Types.undefined)
        recovery_threshold = choose(integer.abs, float.abs, Stoplight::Types.undefined)
        window_size = choose(integer.abs, float.abs, Stoplight::Types.undefined)

        [
          {name:, cool_off_time:, threshold:, recovery_threshold:, window_size:},
          {recovery_threshold:, window_size:, threshold:, name:, cool_off_time:}
        ]
      }.check do |params1, params2|
        dsl1 = described_class.new(**params1)
        dsl2 = described_class.new(**params2)

        expect(dsl1.digest).to eq(dsl2.digest)
      end
    end

    # Property: different params = different digest (collision resistance)
    specify "produces different digests for different parameters" do
      property_of {
        name = string
        cool_off_time = integer
        threshold1 = choose(integer.abs, float.abs, Stoplight::Types.undefined)
        threshold2 = choose(integer.abs, float.abs, Stoplight::Types.undefined)

        [
          {name: name, cool_off_time: cool_off_time, threshold: threshold1},
          {name: name, cool_off_time: cool_off_time, threshold: threshold2}
        ]
      }.check do |params1, params2|
        # Skip if randomly identical
        next if params1[:threshold] == params2[:threshold]

        dsl1 = described_class.new(**params1)
        dsl2 = described_class.new(**params2)

        # Should be different (collisions are theoretically possible but rare)
        expect(dsl1.digest).not_to eq(dsl2.digest)
      end
    end
  end
end

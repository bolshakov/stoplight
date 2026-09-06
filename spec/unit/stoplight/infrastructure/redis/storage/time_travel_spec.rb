# frozen_string_literal: true

RSpec.describe Stoplight::TimeTravel, :redis do
  describe ".freeze" do
    it "sets Ruby and Redis time to the same frozen moment" do
      frozen_time = Time.new(2025, 6, 15, 14, 30, 45)

      Stoplight::TimeTravel.freeze(frozen_time) do
        ruby_time = Time.now
        redis_time_ms = redis.lindex("stoplight:test_now_ms_stack", -1).to_i

        expect(ruby_time.to_i).to eq(frozen_time.to_i)
        expect(redis_time_ms).to eq((frozen_time.to_f * 1000).to_i)
      end
    end

    it "preserves outer context after nested freeze block" do
      start_time = Time.new(2025, 1, 1, 12, 0, 0)
      inner_time = Time.new(2025, 6, 15, 14, 30, 45)

      Stoplight::TimeTravel.freeze(start_time) do
        inner_captured_time = nil
        Stoplight::TimeTravel.freeze(inner_time) do
          inner_captured_time = Time.now
        end

        outer_time = Time.now
        redis_time_ms = redis.lindex("stoplight:test_now_ms_stack", -1).to_i

        expect(outer_time.to_i).to eq(start_time.to_i)
        expect(inner_captured_time.to_i).to eq(inner_time.to_i)
        expect(redis_time_ms).to eq((start_time.to_f * 1000).to_i)
      end
    end

    it "handles non-block freeze with relative offset (integer)" do
      base_time = Time.new(2025, 6, 15, 14, 30, 45)
      offset_seconds = 5000

      Stoplight::TimeTravel.freeze(base_time) do
        # Inside outer frozen time, call non-block freeze with relative offset
        Stoplight::TimeTravel.freeze(offset_seconds)

        ruby_time = Time.now
        redis_stack_value = redis.lindex("stoplight:test_now_ms_stack", -1)

        # Ruby should be at base_time + offset (Timecop interprets integer as relative)
        expected_ruby = (base_time + offset_seconds).to_i
        expect(ruby_time.to_i).to eq(expected_ruby)

        # Redis stack should have the resolved frozen time in milliseconds
        # (what Timecop actually resolved, not the raw offset)
        expected_redis_ms = (ruby_time.to_f * 1000).to_i
        expect(redis_stack_value.to_i).to eq(expected_redis_ms)
      end
    end

    it "clears Redis stack on non-block freeze" do
      base_time = Time.new(2025, 6, 15, 14, 30, 45)
      offset_seconds = 5000

      Stoplight::TimeTravel.freeze(base_time) do
        expect(redis.llen("stoplight:test_now_ms_stack")).to eq(1)

        # Non-block freeze should clear and reset the stack
        Stoplight::TimeTravel.freeze(offset_seconds)

        # Stack should have exactly one entry (not accumulated)
        expect(redis.llen("stoplight:test_now_ms_stack")).to eq(1)
      end
    end
  end
end

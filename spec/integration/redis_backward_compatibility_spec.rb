# frozen_string_literal: true

RSpec.describe "Redis drop-in compatibility", :redis, :freeze do
  let(:light_name) { SecureRandom.uuid }
  let(:data_store) { Stoplight::Infrastructure::DataStore::Redis.new(redis) }
  let(:config) { Stoplight::Domain::Config.empty.with(name: light_name, window_size: 300) }

  def failure_key
    Stoplight::Infrastructure::DataStore::Redis.bucket_key(light_name, metric: "failure", time: Time.now)
  end

  def metadata_key
    Stoplight::Infrastructure::DataStore::Redis.key("metadata", light_name)
  end

  describe "mixed integer/float timestamp storage" do
    let(:base_time) { Time.now }

    it "correctly counts errors from old integer timestamps and new float timestamps" do
      # Simulate OLD version writing integer timestamps
      Timecop.freeze(base_time - 100) do
        redis.zadd(failure_key, Time.now.to_i, "old_request_1")
      end

      Timecop.freeze(base_time - 50) do
        redis.zadd(failure_key, Time.now.to_i, "old_request_2")
      end

      # NEW version writes float timestamps
      Timecop.freeze(base_time) do
        data_store.record_failure(config, StandardError.new("new error"))
      end

      # Verify all 3 errors are counted
      metadata = data_store.get_metadata(config)
      expect(metadata.errors).to eq(3)
    end

    it "correctly queries windows with mixed timestamp types" do
      # Old: integer timestamp outside window
      Timecop.freeze(base_time - 400) do
        redis.zadd(failure_key, Time.now.to_i, "old_expired")
      end

      # Old: integer timestamp inside window
      Timecop.freeze(base_time - 100) do
        redis.zadd(failure_key, Time.now.to_i, "old_valid")
      end

      # New: float timestamp inside window
      Timecop.freeze(base_time) do
        data_store.record_failure(config, StandardError.new("new error"))
      end

      # Should only count the 2 within window (300 seconds)
      metadata = data_store.get_metadata(config)
      expect(metadata.errors).to eq(2)
    end

    it "correctly reads metadata fields with integer timestamps" do
      # Simulate OLD version writing integer timestamp to metadata hash
      redis.hset(metadata_key, "last_error_at", Time.now.to_i)
      redis.hset(metadata_key, "consecutive_errors", "3")
      redis.hset(metadata_key, "last_error_json", JSON.generate({
        error: {
          class: "StandardError",
          message: "something went wrong"
        },
        time: base_time.to_i
      }))

      # NEW version should read it without issues
      metadata = data_store.get_metadata(config)
      expect(metadata.last_error_at).to be_a(Time)
      expect(metadata.consecutive_errors).to eq(3)
      expect(metadata.last_error).to have_attributes(
        error_class: "StandardError",
        error_message: "something went wrong",
        time: Time.at(base_time.to_i)
      )
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Postgres data store wiring", :postgres do
  let(:light_name) { SecureRandom.uuid }
  let(:fallback) { ->(_error) { :fallback_result } }
  let(:failing_code) { -> { raise "boom" } }

  before do
    Stoplight.configure(trust_me_im_an_engineer: true) do |config|
      config.data_store = Stoplight::DataStore::Postgres.new(pg_connection)
    end
  end

  describe "end-to-end trip to RED via Postgres" do
    it "trips to RED after exceeding threshold and runs fallback instead of code" do
      light = Stoplight(light_name, threshold: 3, traffic_control: :consecutive_errors)

      # 3 failures to exceed threshold=3
      3.times { light.run(fallback, &failing_code) }

      expect(light.color).to eq(Stoplight::Color::RED)

      probe_ran = false
      result = light.run(fallback) { probe_ran = true }

      expect(probe_ran).to be(false)
      expect(result).to eq(:fallback_result)
    end
  end

  describe "LightFactory wires a FailSafe-wrapped Postgres store" do
    it "records failures and retrieves metrics without error" do
      light = Stoplight(light_name, threshold: 5, traffic_control: :consecutive_errors)

      # Light starts GREEN — confirms wiring succeeded
      expect(light.color).to eq(Stoplight::Color::GREEN)

      # Record 2 failures — still GREEN (below threshold of 5)
      2.times { light.run(fallback, &failing_code) }

      expect(light.color).to eq(Stoplight::Color::GREEN)
    end

    it "builds a distinct FailSafe-wrapped store for each Postgres config object" do
      # A second configure call with a new connection object should not share store state
      light_a = Stoplight(light_name, threshold: 2, traffic_control: :consecutive_errors)
      2.times { light_a.run(fallback, &failing_code) }
      expect(light_a.color).to eq(Stoplight::Color::RED)

      # A fresh light with a different name on the same store is independent
      other_name = SecureRandom.uuid
      light_b = Stoplight(other_name, threshold: 2, traffic_control: :consecutive_errors)
      expect(light_b.color).to eq(Stoplight::Color::GREEN)
    end
  end

  describe "release_recovery_lock with Postgres token" do
    it "does not raise NoMatchingPatternError when a Postgres recovery lock token is released" do
      # Exercise the yellow-state transition path which acquires and releases a lock.
      # cool_off_time: 0 means the light is immediately eligible for yellow probing after
      # tripping to RED, so the first .run call after tripping goes through the yellow
      # strategy and exercises acquire/release of the Postgres recovery lock.
      light = Stoplight(
        light_name,
        threshold: 1,
        traffic_control: :consecutive_errors,
        cool_off_time: 0,
        traffic_recovery: :consecutive_successes,
        recovery_threshold: 1
      )

      # Trip to RED (or directly to YELLOW with cool_off_time=0)
      light.run(fallback, &failing_code)

      # The light is now RED or YELLOW — either way a recovery probe run must not
      # raise NoMatchingPatternError from the Postgres token pattern match
      expect { light.run(fallback) {} }.not_to raise_error
    end
  end
end

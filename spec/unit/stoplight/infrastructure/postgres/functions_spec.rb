# frozen_string_literal: true

STOPLIGHT_EXPECTED_FUNCTIONS = %w[
  stoplight_get_metrics
  stoplight_record_failure
  stoplight_record_recovery_probe_failure
  stoplight_record_recovery_probe_success
  stoplight_record_success
  stoplight_release_lock
  stoplight_transition_to_green
  stoplight_transition_to_red
  stoplight_transition_to_yellow
].freeze

RSpec.describe Stoplight::Infrastructure::Postgres::DataStore::Functions, :postgres do
  describe "after Schema.create!" do
    it "installs all 9 stoplight functions in the database" do
      installed = pg_connection
        .exec("SELECT proname FROM pg_proc WHERE proname LIKE 'stoplight_%'")
        .map { |r| r["proname"] }

      expect(installed).to include(*STOPLIGHT_EXPECTED_FUNCTIONS)
    end
  end
end

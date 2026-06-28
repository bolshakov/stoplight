# frozen_string_literal: true

require "spec_helper"
require "generators/stoplight/postgres/install_generator"

RSpec.describe Stoplight::Generators::Postgres::InstallGenerator, type: :generator do
  destination File.expand_path("../../../tmp", __dir__)

  # --- Default install (tables + functions) ---

  context "without --update flag (default install)" do
    before do
      prepare_destination
      run_generator
    end

    let(:generated_migration) do
      migration_file("db/migrate/create_stoplight_tables.rb")
    end

    it "creates a migration file in db/migrate" do
      expect(generated_migration).to be_a_migration
    end

    it "has correct syntax" do
      expect(generated_migration).to have_correct_syntax
    end

    it "includes the CreateStoplightTables migration class" do
      expect(generated_migration).to contain(/class CreateStoplightTables/)
    end

    it "creates the stoplight_events table" do
      expect(generated_migration).to contain(/stoplight_events/)
    end

    it "creates the stoplight_metadata table" do
      expect(generated_migration).to contain(/stoplight_metadata/)
    end

    it "creates the stoplight_recovery_metrics table" do
      expect(generated_migration).to contain(/stoplight_recovery_metrics/)
    end

    it "creates the stoplight_states table" do
      expect(generated_migration).to contain(/stoplight_states/)
    end

    it "creates the stoplight_locks table" do
      expect(generated_migration).to contain(/stoplight_locks/)
    end

    it "adds the idx_stoplight_events_window index on stoplight_events" do
      expect(generated_migration).to contain(/idx_stoplight_events_window/)
    end

    it "defines the composite primary key on stoplight_events" do
      expect(generated_migration).to contain(/PRIMARY KEY \(light, metric, event_id\)/)
    end

    it "sets the locked_state column default to 'unlocked' on stoplight_states" do
      expect(generated_migration).to contain(/unlocked/)
    end

    it "sets integer counter columns to not null with DEFAULT 0" do
      expect(generated_migration).to contain(/DEFAULT 0/)
    end

    # --- Type-correctness proofs (the reason for the rewrite) ---

    it "uses timestamptz column type so timestamps match function signatures" do
      expect(generated_migration).to contain(/timestamptz/)
    end

    it "uses text column type so string columns match function signatures" do
      expect(generated_migration).to contain(/\btext\b/)
    end

    it "does not use the Rails t.datetime DSL (which produced timestamp instead of timestamptz)" do
      expect(generated_migration).not_to contain(/t\.datetime/)
    end

    it "does not use the Rails t.string DSL (which produced varchar instead of text)" do
      expect(generated_migration).not_to contain(/t\.string/)
    end

    it "does not use the Rails create_table DSL (replaced by embedded SQL)" do
      expect(generated_migration).not_to contain(/create_table/)
    end

    it "wraps schema DDL and functions in safety_assured" do
      expect(generated_migration).to contain(/safety_assured/)
    end

    # --- pgSQL function embedding ---

    it "embeds the stoplight_record_failure function definition" do
      expect(generated_migration).to contain(/CREATE OR REPLACE FUNCTION stoplight_record_failure/)
    end

    it "embeds the stoplight_get_metrics function definition" do
      expect(generated_migration).to contain(/CREATE OR REPLACE FUNCTION stoplight_get_metrics/)
    end

    it "embeds the stoplight_transition_to_red function definition" do
      expect(generated_migration).to contain(/CREATE OR REPLACE FUNCTION stoplight_transition_to_red/)
    end

    it "embeds all 9 pgSQL function definitions" do
      function_names = %w[
        stoplight_get_metrics
        stoplight_record_failure
        stoplight_record_recovery_probe_failure
        stoplight_record_recovery_probe_success
        stoplight_record_success
        stoplight_release_lock
        stoplight_transition_to_green
        stoplight_transition_to_red
        stoplight_transition_to_yellow
      ]

      function_names.each do |name|
        expect(generated_migration).to contain(/CREATE OR REPLACE FUNCTION #{name}/),
          "expected migration to contain CREATE OR REPLACE FUNCTION #{name}"
      end
    end

    it "drops the functions in the down migration" do
      expect(generated_migration).to contain(/DROP FUNCTION IF EXISTS stoplight_record_failure/)
    end
  end

  # --- Update mode (functions only) ---

  context "with --update flag" do
    before do
      prepare_destination
      run_generator ["--update"]
    end

    let(:update_migration) do
      migration_file("db/migrate/update_stoplight_functions.rb")
    end

    it "creates an update_stoplight_functions migration file" do
      expect(update_migration).to be_a_migration
    end

    it "has correct syntax" do
      expect(update_migration).to have_correct_syntax
    end

    it "includes the UpdateStoplightFunctions migration class" do
      expect(update_migration).to contain(/class UpdateStoplightFunctions/)
    end

    it "embeds the stoplight_record_failure function definition" do
      expect(update_migration).to contain(/CREATE OR REPLACE FUNCTION stoplight_record_failure/)
    end

    it "embeds the stoplight_get_metrics function definition" do
      expect(update_migration).to contain(/CREATE OR REPLACE FUNCTION stoplight_get_metrics/)
    end

    it "embeds all 9 pgSQL function definitions" do
      function_names = %w[
        stoplight_get_metrics
        stoplight_record_failure
        stoplight_record_recovery_probe_failure
        stoplight_record_recovery_probe_success
        stoplight_record_success
        stoplight_release_lock
        stoplight_transition_to_green
        stoplight_transition_to_red
        stoplight_transition_to_yellow
      ]

      function_names.each do |name|
        expect(update_migration).to contain(/CREATE OR REPLACE FUNCTION #{name}/),
          "expected update migration to contain CREATE OR REPLACE FUNCTION #{name}"
      end
    end

    it "does not create any tables" do
      expect(update_migration).not_to contain(/create_table/)
    end

    it "raises IrreversibleMigration in down" do
      expect(update_migration).to contain(/IrreversibleMigration/)
    end

    it "does not create a create_stoplight_tables migration" do
      expect(file("db/migrate/create_stoplight_tables.rb")).not_to exist
    end
  end
end

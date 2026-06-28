# frozen_string_literal: true

RSpec.describe "Stoplight::Infrastructure::Postgres::DataStore::Schema type contract", :postgres do
  # Fetch the data_type for a specific (table, column) pair from information_schema.
  # Returns nil if the column does not exist, so a missing column fails the assertion
  # rather than silently passing.
  def column_type(table, column)
    row = pg_connection.exec_params(
      "SELECT data_type FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
      [table, column]
    ).first
    row&.fetch("data_type")
  end

  describe "timestamptz columns" do
    {
      "stoplight_events" => %w[occurred_at],
      "stoplight_metadata" => %w[last_error_at last_success_at],
      "stoplight_recovery_metrics" => %w[last_error_at last_success_at],
      "stoplight_states" => %w[breached_at recovery_scheduled_after recovery_started_at recovered_at],
      "stoplight_locks" => %w[expires_at]
    }.each do |table, columns|
      columns.each do |col|
        it "#{table}.#{col} is 'timestamp with time zone'" do
          expect(column_type(table, col)).to eq("timestamp with time zone"),
            "Expected #{table}.#{col} to be 'timestamp with time zone' but got " \
            "'#{column_type(table, col)}'. " \
            "Changing this to 'timestamp' or 'character varying' will break the pgSQL functions."
        end
      end
    end
  end

  describe "text columns (must be 'text', NOT 'character varying')" do
    {
      "stoplight_events" => %w[light metric event_id],
      "stoplight_metadata" => %w[light last_error_class last_error_message],
      "stoplight_recovery_metrics" => %w[light last_error_class last_error_message],
      "stoplight_states" => %w[light locked_state],
      "stoplight_locks" => %w[light token]
    }.each do |table, columns|
      columns.each do |col|
        it "#{table}.#{col} is 'text'" do
          expect(column_type(table, col)).to eq("text"),
            "Expected #{table}.#{col} to be 'text' but got '#{column_type(table, col)}'. " \
            "Use 'text' not 'character varying' — the pgSQL functions declare their " \
            "parameters as 'text' and implicit casts can break index usage."
        end
      end
    end
  end

  describe "integer columns" do
    {
      "stoplight_metadata" => %w[consecutive_errors consecutive_successes],
      "stoplight_recovery_metrics" => %w[consecutive_errors consecutive_successes]
    }.each do |table, columns|
      columns.each do |col|
        it "#{table}.#{col} is 'integer'" do
          expect(column_type(table, col)).to eq("integer"),
            "Expected #{table}.#{col} to be 'integer' but got '#{column_type(table, col)}'. " \
            "The pgSQL functions increment these counters directly; a type mismatch will fail."
        end
      end
    end
  end
end

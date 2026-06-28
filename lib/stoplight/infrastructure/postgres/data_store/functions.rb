# frozen_string_literal: true

# steep:ignore:start
module Stoplight
  module Infrastructure
    module Postgres
      class DataStore
        # Installs pgSQL functions that implement atomic stoplight operations.
        #
        # Mirrors the Redis adapter's Scripting module: SQL files under functions/
        # are loaded once at schema creation time so the adapter can call them via
        # exec_params instead of inlining multi-statement SQL.
        module Functions
          current_dir = __dir__ or raise "Cannot determine functions directory"
          FUNCTIONS_ROOT = File.join(current_dir, "functions")
          private_constant :FUNCTIONS_ROOT

          # @return [String] concatenated SQL of all function definitions (sorted)
          def self.sql
            Dir[File.join(FUNCTIONS_ROOT, "*.sql")].sort.map { |f| File.read(f) }.join("\n")
          end

          # @param conn [PG::Connection]
          # @return [void]
          def self.install!(conn)
            conn.exec(sql)
          end
        end
      end
    end
  end
end
# steep:ignore:end

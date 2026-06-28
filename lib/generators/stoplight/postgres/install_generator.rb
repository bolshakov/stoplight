# frozen_string_literal: true

begin
  require "rails/generators"
  require "rails/generators/migration"
rescue LoadError
  raise <<~WARN
    Currently generators are only available for Rails applications
  WARN
end

require "stoplight/infrastructure/postgres/data_store/schema"
require "stoplight/infrastructure/postgres/data_store/functions"

# steep:ignore:start
module Stoplight
  module Generators
    module Postgres
      class InstallGenerator < ::Rails::Generators::Base # :nodoc:
        include ::Rails::Generators::Migration

        class_option :update, type: :boolean, default: false,
          desc: "Generate a migration that only refreshes the pgSQL functions"

        case (root = __dir__)
        when String
          source_root File.expand_path("templates", root)
        else
          raise "cannot find templates root"
        end

        # Required by Rails::Generators::Migration. Returns the next migration
        # version number. When ActiveRecord is available (Rails app), delegates
        # to AR's counter so timestamps stay monotonic; otherwise falls back to
        # a plain UTC timestamp string.
        def self.next_migration_number(dirname)
          if defined?(::ActiveRecord::Generators::Base)
            ::ActiveRecord::Generators::Base.next_migration_number(dirname)
          else
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          end
        end

        def create_migration_file
          if options[:update]
            migration_template(
              "update_stoplight_functions.rb.erb",
              "db/migrate/update_stoplight_functions.rb"
            )
          else
            migration_template(
              "create_stoplight_tables.rb.erb",
              "db/migrate/create_stoplight_tables.rb"
            )
          end
        end

        private

        # Returns the ActiveRecord::Migration version string (e.g. "8.0") derived
        # from the running Rails version, without requiring activerecord to be
        # loaded. Used in the migration template as <%= migration_version %>.
        def migration_version
          "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
        end

        # Returns the concatenated SQL of all pgSQL function definitions.
        # Embedded into the generated migration at generation time so migrations
        # remain self-contained and reproducible (logidze-style).
        #
        # Thor reads ERB template files with File.binread, so the ERB output buffer
        # is ASCII-8BIT. Any non-ASCII characters in the interpolated SQL (e.g.,
        # em-dashes in comments) cause an Encoding::CompatibilityError. We encode
        # to ASCII, replacing non-ASCII code points with their closest ASCII
        # equivalent. SQL syntax is always ASCII; only comments may contain Unicode.
        def stoplight_functions_sql
          Stoplight::Infrastructure::Postgres::DataStore::Functions.sql
            .encode("ASCII", invalid: :replace, undef: :replace, replace: "-")
        end

        # Returns the canonical tables DDL (text / timestamptz columns). Embedded
        # into the migration so the generated tables always match the column types
        # the pgSQL functions expect. See stoplight_functions_sql for the ASCII note.
        def stoplight_schema_sql
          Stoplight::Infrastructure::Postgres::DataStore::Schema::SQL
            .encode("ASCII", invalid: :replace, undef: :replace, replace: "-")
        end
      end
    end
  end
end
# steep:ignore:end

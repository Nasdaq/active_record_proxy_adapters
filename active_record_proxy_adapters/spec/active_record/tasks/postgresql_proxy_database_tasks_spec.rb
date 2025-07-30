# frozen_string_literal: true

require "shared_examples/a_database_task"

RSpec.describe ActiveRecord::Tasks::PostgreSQLProxyDatabaseTasks do # rubocop:disable RSpec/SpecFilePathFormat
  it_behaves_like "a database task" do
    let(:public_schema_config) do
      configuration.configuration_hash.merge(adapter: "postgresql", database: "postgres", schema_search_path: "public")
    end
    let(:configuration) do
      TestHelper.postgresql_database_tasks_configuration
    end

    let(:model_class) { TestHelper::PostgreSQLDatabaseTaskRecord }
    let(:structure_path) { "db/postgresql_structure.sql" }
    let(:schema) { File.read(structure_path) }

    def database_exists?
      proc do
        with_master_connection do |conn|
          conn.select_value <<~SQL.squish
            SELECT COUNT(*)::int::boolean
            FROM pg_database WHERE datname = '#{configuration.database}';
          SQL
        end
      end
    end
  end
end

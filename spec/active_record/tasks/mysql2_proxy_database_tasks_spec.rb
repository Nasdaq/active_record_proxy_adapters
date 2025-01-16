# frozen_string_literal: true

require "shared_examples/a_database_task"

RSpec.describe ActiveRecord::Tasks::Mysql2ProxyDatabaseTasks do
  it_behaves_like "a database task" do
    let(:public_schema_config) do
      configuration.configuration_hash.merge(adapter: "mysql2", database: nil)
    end
    let(:configuration) do
      TestHelper.mysql2_database_tasks_configuration
    end

    let(:model_class) { TestHelper::Mysql2DatabaseTaskRecord }
    let(:structure_path) { "db/mysql_structure.sql" }

    def database_exists?
      proc do
        with_master_connection do |conn|
          count = conn.select_value <<~SQL.squish
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.SCHEMATA
            WHERE SCHEMA_NAME = '#{configuration.database}';
          SQL

          count.positive?
        end
      end
    end

    def schema_matches?
      proc { strip_comments(temp_file.read) == strip_comments(schema) }
    end

    def strip_comments(string)
      string.gsub(%r{/\*.+?\*/;?\s+}, "").strip
    end
  end
end

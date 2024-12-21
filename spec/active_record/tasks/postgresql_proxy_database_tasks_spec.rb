# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe ActiveRecord::Tasks::PostgreSQLProxyDatabaseTasks do # rubocop:disable RSpec/SpecFilePathFormat
  let(:public_schema_config) do
    configuration.configuration_hash.merge(adapter: "postgresql", database: "postgres", schema_search_path: "public")
  end
  let(:configuration) do
    TestHelper.postgresql_database_tasks_configuration
  end

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

  def schema_loaded?
    proc do
      any_tables = TestHelper::PostgreSQLDatabaseTaskRecord.connection.tables.any?
      TestHelper::PostgreSQLDatabaseTaskRecord.connection_pool.disconnect!

      any_tables
    end
  end

  def with_master_connection(&)
    pool = ActiveRecord::Base.connection_handler.establish_connection(public_schema_config,
                                                                      role: :admin)
    pool.with_connection(&)
  ensure
    pool.disconnect
  end

  describe "#drop" do
    subject(:drop) { ActiveRecord::Tasks::DatabaseTasks.drop(configuration) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
    end

    it "drops the database" do
      expect { drop }.to change(&database_exists?).from(true).to(false)
    end
  end

  describe "#create" do
    subject(:create) { ActiveRecord::Tasks::DatabaseTasks.create(configuration) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "creates the database" do
      expect { create }.to change(&database_exists?).from(false).to(true)
    end
  end

  describe "#structure_load" do
    subject(:structure_load) do
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, "db/postgresql_structure.sql")
    end

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "loads the schema" do
      expect { structure_load }.to change(&schema_loaded?).from(false).to(true)
    end
  end

  describe "#structure_dump" do
    subject(:structure_dump) { ActiveRecord::Tasks::DatabaseTasks.structure_dump(configuration, dump_out) }

    let(:dump_out) { temp_file.path }
    let(:dump_in) { "db/postgresql_structure.sql" }
    let(:temp_file) { Tempfile.create("postgresql_structure.sql") }
    let(:schema) { File.read(dump_in) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, dump_in)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "dumps the schema onto the given path" do
      schema_matches = proc { temp_file.read == schema }

      expect { structure_dump }.to change(&schema_matches).from(false).to(true)
    end
  end

  describe "#purge" do
    subject(:purge) do
      ActiveRecord::Tasks::DatabaseTasks.purge(configuration)
    end

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, "db/postgresql_structure.sql")
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "recreates the database with an empty schema" do
      expect { purge }.to change(&schema_loaded?).from(true).to(false)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers

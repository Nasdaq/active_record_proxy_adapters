# frozen_string_literal: true

RSpec.shared_examples_for "a database task" do
  let(:public_schema_config) { configuration.configuration_hash }
  let(:configuration) { nil }
  let(:model_class) { nil }
  let(:structure_path) { nil }
  let(:migration_context) do
    active_record_context = ActiveRecordProxyAdapters::ActiveRecordContext.new
    migration_context_store = if active_record_context.active_record_v7_2_or_greater?
                                ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
                              else
                                ActiveRecord::Tasks::DatabaseTasks.migration_connection
                              end
    migration_context_store.migration_context
  end

  def migration_target_version
    Dir[File.expand_path("../db/database_tasks_migrate/*.rb", __dir__)]
      .first
      .split("/")
      .last
      .split("_")
      .first
      .to_i
  end

  def database_exists?
    raise NoMethodError, "database_exists? must be implemented in the including context"
  end

  def schema_loaded?
    proc do
      pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool(
        model_class.name, role: TestHelper.writing_role
      )
      any_tables = model_class.connected_to(role: TestHelper.writing_role) do
        model_class.connection.tables.any?
      end

      pool.disconnect!

      any_tables
    end
  end

  def schema_matches?
    proc { cleanup_schema(temp_file.read) == cleanup_schema(schema) }
  end

  def cleanup_schema(schema)
    # Remove /restrict and /unrestrict tags from the sql file as those are randomly generated
    # Remove "Dumped from/by comments"
    schema
      .gsub(/^\\(un)?restrict.*\n+/, "")
      .gsub(/^--\s+Dumped.+\n+/, "")
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
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
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

  describe "#structure_dump" do # rubocop:disable RSpec/MultipleMemoizedHelpers
    subject(:structure_dump) { ActiveRecord::Tasks::DatabaseTasks.structure_dump(configuration, dump_out) }

    let(:dump_out) { temp_file.path }
    let(:dump_in) { structure_path }
    let(:temp_file) { Tempfile.create(structure_path) }
    let(:schema) { File.read(dump_in) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, dump_in)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "dumps the schema onto the given path" do
      expect { structure_dump }.to change(&schema_matches?).from(false).to(true)
    end
  end

  describe "#purge" do
    subject(:purge) { ActiveRecord::Tasks::DatabaseTasks.purge(configuration) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "recreates the database with an empty schema" do
      expect { purge }.to change(&schema_loaded?).from(true).to(false)
    end
  end

  describe "#forward" do
    subject(:forward) { migration_context.forward(1) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(migration_context).to receive(:sticking_to_primary).and_call_original

      forward

      expect(migration_context).to have_received(:sticking_to_primary)
    end
  end

  describe "#rollback" do
    subject(:rollback) { migration_context.rollback(1) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(migration_context).to receive(:sticking_to_primary).and_call_original

      rollback

      expect(migration_context).to have_received(:sticking_to_primary)
    end
  end

  describe "#up" do
    subject(:up) { migration_context.run(:up, migration_target_version) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(migration_context).to receive(:sticking_to_primary).and_call_original

      up

      expect(migration_context).to have_received(:sticking_to_primary)
    end
  end

  describe "#down" do
    subject(:down) { migration_context.run(:down, migration_target_version) }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
      migration_context.run(:up, "20250102000000".to_i)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(migration_context).to receive(:sticking_to_primary).and_call_original

      down

      expect(migration_context).to have_received(:sticking_to_primary)
    end
  end

  describe "#migrate" do
    subject(:migrate) { ActiveRecord::Tasks::DatabaseTasks.migrate }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:sticking_to_primary).and_call_original

      migrate

      expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:sticking_to_primary)
    end
  end

  describe "#migrate_status" do
    subject(:migrate_status) { ActiveRecord::Tasks::DatabaseTasks.migrate_status }

    before do
      ActiveRecord::Tasks::DatabaseTasks.create(configuration)
      ActiveRecord::Tasks::DatabaseTasks.structure_load(configuration, structure_path)
      ActiveRecord::Base.establish_connection(configuration)
    end

    after do
      ActiveRecord::Tasks::DatabaseTasks.drop(configuration)
    end

    it "reroutes requests to the primary" do
      allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:sticking_to_primary).and_call_original

      migrate_status

      expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:sticking_to_primary)
    end
  end
end

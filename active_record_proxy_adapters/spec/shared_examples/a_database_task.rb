# frozen_string_literal: true

RSpec.shared_examples_for "a database task" do
  let(:public_schema_config) { configuration.configuration_hash }
  let(:configuration) { nil }
  let(:model_class) { nil }
  let(:structure_path) { nil }

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
    proc { temp_file.read == schema }
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
end

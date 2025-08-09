# frozen_string_literal: true

require "erb"

module TestHelper # rubocop:disable Metrics/ModuleLength
  module_function

  class PostgreSQLRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class PostgreSQLDatabaseTaskRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class Mysql2Record < ActiveRecord::Base
    self.abstract_class = true
  end

  class Mysql2DatabaseTaskRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class TrilogyRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class TrilogyDatabaseTaskRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class SQLite3Record < ActiveRecord::Base
    self.abstract_class = true
  end

  class SQLite3DatabaseTaskRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  def env_name
    ENV["RAILS_ENV"] || "test"
  end

  def setup_active_record_config
    active_record_context.legacy_connection_handling = false
    active_record_context.writing_role = :writing
    active_record_context.reading_role = :reading

    load_configurations

    nil
  end

  def reading_role
    active_record_context.reading_role
  end

  def writing_role
    active_record_context.writing_role
  end

  def postgresql_primary_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(PostgreSQLRecord.name, role: writing_role)
  end

  def postgresql_replica_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(PostgreSQLRecord.name, role: reading_role)
  end

  def mysql2_primary_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(Mysql2Record.name, role: writing_role)
  end

  def mysql2_replica_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(Mysql2Record.name, role: reading_role)
  end

  def trilogy_primary_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(TrilogyRecord.name, role: writing_role)
  end

  def trilogy_replica_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(TrilogyRecord.name, role: reading_role)
  end

  def sqlite3_primary_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(SQLite3Record.name, role: writing_role)
  end

  def sqlite3_replica_pool
    ActiveRecord::Base
      .connection_handler
      .retrieve_connection_pool(SQLite3Record.name, role: reading_role)
  end

  def reset_database
    drop_postgresql_database
    create_postgresql_database
    drop_mysql2_database
    create_mysql2_database
    drop_trilogy_database
    create_trilogy_database
  end

  def drop_postgresql_database
    ActiveRecord::Tasks::DatabaseTasks.drop(postgresql_primary_configuration)
  end

  def create_postgresql_database
    ActiveRecord::Tasks::DatabaseTasks.create(postgresql_primary_configuration)
  end

  def drop_mysql2_database
    ActiveRecord::Tasks::DatabaseTasks.drop(mysql2_primary_configuration)
  end

  def create_mysql2_database
    ActiveRecord::Tasks::DatabaseTasks.create(mysql2_primary_configuration)
  end

  def drop_trilogy_database
    ActiveRecord::Tasks::DatabaseTasks.drop(trilogy_primary_configuration)
  end

  def create_trilogy_database
    ActiveRecord::Tasks::DatabaseTasks.create(trilogy_primary_configuration)
  end

  def drop_sqlite3_database
    ActiveRecord::Tasks::DatabaseTasks.drop(sqlite3_primary_configuration)
  end

  def create_sqlite3_database
    ActiveRecord::Tasks::DatabaseTasks.create(sqlite3_primary_configuration)
  end

  def load_postgresql_schema(structure_path = "db/postgresql_structure.sql")
    ActiveRecord::Tasks::DatabaseTasks.structure_load(postgresql_primary_configuration, structure_path)
  end

  def dump_postgresql_schema(structure_path = "db/postgresql_structure.sql")
    ActiveRecord::Base.establish_connection(postgresql_primary_configuration)
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(postgresql_primary_configuration, structure_path)
  end

  def load_mysql2_schema(structure_path = "db/mysql_structure.sql")
    ActiveRecord::Tasks::DatabaseTasks.structure_load(mysql2_primary_configuration, structure_path)
  end

  def dump_mysql2_schema(structure_path = "db/mysql_structure.sql")
    ActiveRecord::Base.establish_connection(mysql2_primary_configuration)
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(mysql2_primary_configuration, structure_path)
  end

  def load_trilogy_schema(structure_path = "db/mysql_structure.sql")
    ActiveRecord::Tasks::DatabaseTasks.structure_load(trilogy_primary_configuration, structure_path)
  end

  def dump_trilogy_schema(structure_path = "db/mysql_structure.sql")
    ActiveRecord::Base.establish_connection(trilogy_primary_configuration)
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(trilogy_primary_configuration, structure_path)
  end

  def load_sqlite3_schema(structure_path = "db/sqlite3_structure.sql")
    ActiveRecord::Tasks::DatabaseTasks.structure_load(sqlite3_primary_configuration, structure_path)
  end

  def dump_sqlite3_schema(structure_path = "db/sqlite3_structure.sql")
    ActiveRecord::Base.establish_connection(sqlite3_primary_configuration)
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(sqlite3_primary_configuration, structure_path)
  end

  def postgresql_primary_configuration
    configuration_for(name: "postgresql_primary")
  end

  def postgresql_replica_configuration
    configuration_for(name: "postgresql_replica", include_hidden: true)
  end

  def postgresql_database_tasks_configuration
    configuration_for(name: "postgresql_database_tasks")
  end

  def mysql2_primary_configuration
    configuration_for(name: "mysql2_primary")
  end

  def mysql2_replica_configuration
    configuration_for(name: "mysql2_replica", include_hidden: true)
  end

  def mysql2_database_tasks_configuration
    configuration_for(name: "mysql2_database_tasks")
  end

  def trilogy_primary_configuration
    configuration_for(name: "trilogy_primary")
  end

  def trilogy_replica_configuration
    configuration_for(name: "trilogy_replica", include_hidden: true)
  end

  def trilogy_database_tasks_configuration
    configuration_for(name: "trilogy_database_tasks")
  end

  def sqlite3_primary_configuration
    configuration_for(name: "sqlite3_primary")
  end

  def sqlite3_replica_configuration
    configuration_for(name: "sqlite3_replica")
  end

  def sqlite3_database_tasks_configuration
    configuration_for(name: "sqlite3_database_tasks")
  end

  def configuration_for(name:, include_hidden: false)
    configurations = ActiveRecord::Base.configurations

    options = { env_name: env_name.to_s, name: }

    if ActiveRecord.version < Gem::Version.new("7.1")
      options.merge!(include_replicas: include_hidden)
    else
      options.merge!(include_hidden:)
    end

    configurations.configs_for(**options)
  end

  def load_configurations
    ActiveRecord::Tasks::DatabaseTasks.root = File.expand_path("..", __dir__)
    ActiveRecord::Base.configurations = database_config

    load_postgresql_configuration
    load_mysql2_configuration
    load_trilogy_configuration
    load_sqlite3_configuration

    ActiveRecordProxyAdapters.configure do |config|
      config.log_subscriber_primary_prefix = "Primary"
      config.log_subscriber_replica_prefix = "Replica"
    end
  end

  def load_postgresql_configuration
    PostgreSQLRecord.connects_to(database: { writing_role => :postgresql_primary, reading_role => :postgresql_replica })
    PostgreSQLDatabaseTaskRecord.connects_to(database: { writing_role => :postgresql_database_tasks })
  end

  def load_mysql2_configuration
    Mysql2Record.connects_to(database: { writing_role => :mysql2_primary, reading_role => :mysql2_replica })
    Mysql2DatabaseTaskRecord.connects_to(database: { writing_role => :mysql2_database_tasks })
  end

  def load_trilogy_configuration
    TrilogyRecord.connects_to(database: { writing_role => :trilogy_primary, reading_role => :trilogy_replica })
    TrilogyDatabaseTaskRecord.connects_to(database: { writing_role => :trilogy_database_tasks })
  end

  def load_sqlite3_configuration
    SQLite3Record.connects_to(database: { writing_role => :sqlite3_primary, reading_role => :sqlite3_replica })
    SQLite3DatabaseTaskRecord.connects_to(database: { writing_role => :sqlite3_database_tasks })
  end

  def database_config
    filepath      = File.expand_path("config/database.yml", __dir__)
    config_string = File.read(filepath)
    erb           = ERB.new(config_string)
    YAML.safe_load(erb.result, aliases: true)
  end

  def truncate_postgresql_database
    truncate_database(postgresql_primary_pool, suffix: "RESTART IDENTITY CASCADE")
  end

  def truncate_mysql2_database
    truncate_database(mysql2_primary_pool)
  end

  def truncate_trilogy_database
    truncate_database(trilogy_primary_pool)
  end

  def truncate_sqlite3_database
    sqlite3_primary_pool.with_connection do |connection|
      connection.tables.each do |table|
        connection.execute_unproxied <<~SQL.squish
          DELETE FROM #{table};
        SQL
      end
    end
  end

  def truncate_database(pool, suffix: "")
    pool.with_connection do |connection|
      connection.tables.each do |table|
        connection.execute_unproxied <<~SQL.squish
          TRUNCATE TABLE #{table} #{suffix};
        SQL
      end
    end
  end

  def with_temporary_pool(model_class, &)
    config = model_class.connection_db_config
    if active_record_context.active_record_v7_2_or_greater?
      with_rails_v7_2_or_greater_temporary_pool(config, &)
    elsif active_record_context.active_record_v7_1_or_greater?
      with_rails_v7_1_temporary_pool(config, &)
    else
      with_rails_v7_0_temporary_pool(model_class, &)
    end
  end

  def with_rails_v7_2_or_greater_temporary_pool(config)
    ActiveRecord::PendingMigrationConnection.with_temporary_pool(config) do |pool|
      yield(pool, pool.schema_migration, pool.internal_metadata)
    end
  end

  def with_rails_v7_1_temporary_pool(config)
    ActiveRecord::PendingMigrationConnection.establish_temporary_connection(config) do |conn|
      yield(conn.pool, conn.schema_migration, conn.internal_metadata)
    end
  end

  def with_rails_v7_0_temporary_pool(model_class)
    conn = model_class.connection

    yield(conn.pool, conn.schema_migration, nil)
  end

  def active_record_context
    @active_record_context ||= ActiveRecordProxyAdapters::ActiveRecordContext.new
  end
end

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

  def reset_database
    drop_postgresql_database
    create_postgresql_database
    drop_mysql2_database
    create_mysql2_database
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
    ActiveRecord::Base.configurations = database_config
    PostgreSQLRecord.connects_to(database: { writing_role => :postgresql_primary, reading_role => :postgresql_replica })
    PostgreSQLDatabaseTaskRecord.connects_to(database: { writing_role => :postgresql_database_tasks })

    Mysql2Record.connects_to(database: { writing_role => :mysql2_primary, reading_role => :mysql2_replica })
    Mysql2DatabaseTaskRecord.connects_to(database: { writing_role => :mysql2_database_tasks })
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

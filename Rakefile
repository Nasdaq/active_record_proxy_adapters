# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Prepares the database environment for use"
task :environment do
  trilogy_loaded = begin
    require "activerecord-trilogy-adapter"
  rescue LoadError
    false
  end
  $LOAD_PATH << File.expand_path("lib", __dir__)
  require "active_record_proxy_adapters"
  require_relative "spec/test_helper"

  if trilogy_loaded
    ActiveSupport.on_load(:active_record) do
      require "trilogy_adapter/connection"
      ActiveRecord::Base.extend TrilogyAdapter::Connection
    end
  end

  require "active_record_proxy_adapters/connection_handling"

  ActiveSupport.on_load(:active_record) do
    TestHelper.setup_active_record_config

    $stdout.puts "Environment loaded: #{TestHelper.env_name}"
  end
end

namespace :db do # rubocop:disable Metrics/BlockLength
  desc "Drops all databases"
  task drop: %i[drop:postgresql drop:mysql2 drop:trilogy drop:sqlite3]

  namespace :drop do
    desc "Drops the postgresql database"
    task postgresql: :environment do
      TestHelper.drop_postgresql_database
    end

    desc "Drops the mysql database"
    task mysql2: :environment do
      TestHelper.drop_mysql2_database
    end

    desc "Drops the trilogy database"
    task trilogy: :environment do
      TestHelper.drop_trilogy_database
    end

    desc "Drops the sqlite3 database"
    task sqlite3: :environment do
      TestHelper.drop_sqlite3_database
    end
  end

  desc "Creates all databases"
  task create: %i[create:postgresql create:mysql2 create:trilogy create:sqlite3]

  namespace :create do
    desc "Creates the postgresql database"
    task postgresql: :environment do
      TestHelper.create_postgresql_database
    end

    desc "Creates the mysql database"
    task mysql2: :environment do
      TestHelper.create_mysql2_database
    end

    desc "Creates the trilogy database"
    task trilogy: :environment do
      TestHelper.create_trilogy_database
    end

    desc "Creates the sqlite3 database"
    task sqlite3: :environment do
      TestHelper.create_sqlite3_database
    end
  end

  namespace :schema do # rubocop:disable Metrics/BlockLength
    desc "Loads all schemas onto their respective databases"
    task load: %i[load:postgresql load:mysql2 load:trilogy load:sqlite3]

    namespace :load do
      desc "Loads the schema into the postgresql database from schema_path. Default is db/postgresql_structure.sql"
      task :postgresql, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/postgresql_structure.sql")
        TestHelper.load_postgresql_schema(args.schema_path)
      end

      desc "Loads the schema into the mysql database from schema_path. Default is db/mysql_structure.sql"
      task :mysql2, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/mysql_structure.sql")
        TestHelper.load_mysql2_schema(args.schema_path)
      end

      desc "Loads the schema into the trilogy database from schema_path. Default is db/mysql_structure.sql"
      task :trilogy, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/mysql_structure.sql")
        TestHelper.load_trilogy_schema(args.schema_path)
      end

      desc "Loads the schema into the sqlite3 database from schema_path. Default is db/sqlite3_structure.sql"
      task :sqlite3, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/sqlite3_structure.sql")
        TestHelper.load_sqlite3_schema(args.schema_path)
      end
    end

    desc "Dumps all schemas onto their respective files"
    task dump: %i[dump:postgresql dump:mysql2 dump:trilogy dump:sqlite3]

    namespace :dump do
      desc "Dump the schema from the postgresql database onto schema_path. Default is db/postgresql_structure.sql"
      task :postgresql, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/postgresql_structure.sql")
        TestHelper.dump_postgresql_schema(args.schema_path)
      end

      desc "Dump the schema from the mysql database onto schema_path. Default is db/mysql_structure.sql"
      task :mysql2, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/mysql_structure.sql")
        TestHelper.dump_mysql2_schema(args.schema_path)
      end

      desc "Dump the schema from the trilogy database onto schema_path. Default is db/mysql_structure.sql"
      task :trilogy, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/mysql_structure.sql")
        TestHelper.dump_trilogy_schema(args.schema_path)
      end

      desc "Dump the schema from the sqlite3 database onto schema_path. Default is db/sqlite3_structure.sql"
      task :sqlite3, [:schema_path] => :environment do |_task, args|
        args.with_defaults(schema_path: "db/sqlite3_structure.sql")
        TestHelper.dump_sqlite3_schema(args.schema_path)
      end
    end
  end

  desc "Creates a all databases and loads their schemas"
  task setup: %i[create schema:load]

  namespace :setup do
    desc "Creates the postgresql database and loads the schema"
    task postgresql: %i[create:postgresql schema:load:postgresql]

    desc "Creates the mysql2 database and loads the schema"
    task mysql2: %i[create:mysql2 schema:load:mysql2]

    desc "Creates the trilogy database and loads the schema"
    task trilogy: %i[create:trilogy schema:load:trilogy]
  end
end

namespace :coverage do
  desc "Collates all result sets generated by the different test runners"
  task :report do
    require "simplecov"
    require_relative "spec/simple_cov_groups"

    SimpleCov.collate Dir["coverage/**/.resultset.json"] do
      SIMPLE_COV_GROUPS.call
    end
  end
end

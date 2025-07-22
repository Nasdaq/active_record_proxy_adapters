# frozen_string_literal: true

require "logger"
require "benchmark"

module CacheStoreBenchmark
  BENCHMARK_QUERIES = [<<~SQL1.squish, <<~SQL2.squish, <<~SQL3.squish, <<~SQL4.squish, <<~SQL5.squish].freeze
    SELECT COUNT(*) FROM "users"
  SQL1
    SELECT "users".* FROM "users"
  SQL2
    WITH recent_user_ids AS (
      SELECT "id"
      FROM "users"
      WHERE "created_at" >= '2023-10-01 00:00:00' AND "created_at" < '2023-11-01 00:00:00'
    )
    SELECT "email"
    FROM "users"
    WHERE EXISTS (SELECT 1 FROM recent_user_ids WHERE recent_user_ids.id = users.id)
  SQL3
    WITH "recent_user_ids" AS (
      SELECT "id"
      FROM "users"
      WHERE "created_at" >= '2023-10-01 00:00:00' AND "created_at" < '2023-11-01 00:00:00'
    )
    UPDATE "users"
    SET updated_at = NOW()
    FROM "users", "recent_user_ids"
    WHERE NOT EXISTS (SELECT 1 FROM "recent_user_ids" WHERE "recent_user_ids.id" = users.id)
  SQL4
    INSERT INTO "users" (name, email)
    VALUES ('John Doe', 'john.doe@gmail.com')
  SQL5

  class PostgreSQLUser < TestHelper::PostgreSQLRecord
    self.table_name = "users"
  end

  def run(cache_store, iterations: nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    ActiveRecordProxyAdapters.configure { |config| config.cache.store = cache_store }

    connection = PostgreSQLUser.connection
    proxy      = connection.send(:proxy)

    ActiveRecord::Base.logger ||= Logger.new($stdout)
    log_level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = :fatal

    label = cache_store.class.name
    iterations ||= 100_000

    begin
      ActiveRecordProxyAdapters.bust_query_cache
    rescue NotImplementedError
      cache_store.clear
    end

    $stdout.puts "Cache busted for #{label}."
    $stdout.puts "Benchmarking #{label} cache store with #{iterations} iterations."

    Benchmark.bmbm do |bm|
      bm.report(label) do
        iterations.times do
          query = BENCHMARK_QUERIES.sample
          proxy.send(:roles_for, query)
        end
      end
    end
    ActiveRecord::Base.logger.level = log_level

    $stdout.puts "Benchmarking completed for #{label} cache store."
  end

  module_function :run
end

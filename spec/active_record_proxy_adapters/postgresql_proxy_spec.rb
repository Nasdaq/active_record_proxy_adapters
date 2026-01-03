# frozen_string_literal: true

require "shared_examples/a_proxied_method"
require "shared_examples/a_transaction_block_proxy_bypass"

RSpec.describe ActiveRecordProxyAdapters::PostgreSQLProxy do # rubocop:disable RSpec/SpecFilePathFormat
  attr_reader :primary_adapter

  let(:replica_pool) { TestHelper.postgresql_replica_pool }
  let(:primary_pool) { TestHelper.postgresql_primary_pool }
  let(:adapter_class) { ActiveRecord::ConnectionAdapters::PostgreSQLAdapter }
  let(:model_class) { TestHelper::PostgreSQLRecord }

  around do |example|
    primary_pool.with_connection do |connection|
      @primary_adapter = connection

      example.run

      @primary_adapter = nil
    end

    TestHelper.truncate_postgresql_database
  end

  def create_dummy_user
    primary_adapter.execute_unproxied <<~SQL.strip
      INSERT INTO users (name, email)
      VALUES ('John Doe', 'john.doe@example.com')
    SQL
  end

  shared_examples_for "a PostgreSQL CTE" do
    context "when query is contains a CTE" do
      context "when no writes" do
        it_behaves_like "a SQL read statement" do
          let(:sql) do
            <<~SQL.squish
              WITH user_ids AS (
                SELECT id FROM users
              ),
              user_emails AS (
                SELECT email FROM users
              )
              SELECT users.*
              FROM users
              INNER JOIN user_ids ON users.id = user_ids.id
              INNER JOIN user_emails ON users.email = user_emails.email;
            SQL
          end
        end
      end

      context "when there are writes" do
        it_behaves_like "a SQL write statement" do
          let(:sql) do
            <<~SQL.squish
              WITH user_ids AS (
                SELECT id FROM users
              ),
              user_emails AS (
                SELECT email FROM users
              )
              INSERT INTO users
              SELECT users.*
              FROM users
              INNER JOIN user_ids ON users.id = user_ids.id
              INNER JOIN user_emails ON users.email = user_emails.email
            SQL
          end

          let(:read_only_error_class) { ActiveRecord::StatementInvalid }
        end
      end
    end
  end

  shared_examples_for "a ridiculously long SQL write" do
    context "when query is a ridiculously long insert statement" do
      let(:sql) do
        values = 1_000_000.times.map { |i| "('User #{i}', 'user#{i}@example.com')" }

        <<~SQL.squish
          INSERT INTO users (name, email)
          VALUES
          #{values.join(", ")}
        SQL
      end

      it "does not crash" do
        expect { run_test }.not_to raise_error
      end
    end
  end

  it_behaves_like "a transaction block proxy bypass"

  describe "#execute" do
    it_behaves_like "a proxied method", :execute do
      it_behaves_like "a PostgreSQL CTE"
      it_behaves_like "a ridiculously long SQL write"
      it_behaves_like "a SQL pattern matching timeout"
    end
  end
end

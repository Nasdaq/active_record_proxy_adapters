# frozen_string_literal: true

require "shared_examples/a_proxied_method"

RSpec.describe ActiveRecordProxyAdapters::SQLite3Proxy do # rubocop:disable RSpec/SpecFilePathFormat
  attr_reader :primary_adapter

  let(:replica_pool) { TestHelper.sqlite3_replica_pool }
  let(:primary_pool) { TestHelper.sqlite3_primary_pool }
  let(:adapter_class) { ActiveRecord::ConnectionAdapters::SQLite3Adapter }
  let(:model_class) { TestHelper::SQLite3Record }

  around do |example|
    primary_pool.with_connection do |connection|
      @primary_adapter = connection

      example.run

      @primary_adapter = nil
    end

    TestHelper.truncate_sqlite3_database
  end

  def create_dummy_user
    primary_adapter.execute_unproxied <<~SQL.strip
      INSERT INTO users (name, email)
      VALUES ('John Doe', 'john.doe@example.com');
    SQL
  end

  describe "#execute" do
    it_behaves_like "a proxied method", :execute do
      it_behaves_like "a SQL pattern matching timeout"
    end
  end
end

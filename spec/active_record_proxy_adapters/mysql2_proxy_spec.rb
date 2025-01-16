# frozen_string_literal: true

require "shared_examples/a_proxied_method"

RSpec.describe ActiveRecordProxyAdapters::Mysql2Proxy do
  attr_reader :primary_adapter

  let(:replica_pool) { TestHelper.mysql2_replica_pool }
  let(:primary_pool) { TestHelper.mysql2_primary_pool }
  let(:adapter_class) { ActiveRecord::ConnectionAdapters::Mysql2Adapter }
  let(:model_class) { TestHelper::Mysql2Record }

  around do |example|
    primary_pool.with_connection do |connection|
      @primary_adapter = connection

      example.run

      @primary_adapter = nil
    end

    TestHelper.truncate_mysql2_database
  end

  def create_dummy_user
    primary_adapter.execute_unproxied <<~SQL.strip
      INSERT INTO users (name, email)
      VALUES ('John Doe', 'john.doe@example.com');
    SQL
  end

  describe "#execute" do
    it_behaves_like "a proxied method", :execute
  end

  describe "#exec_query" do
    it_behaves_like "a proxied method", :exec_query
  end
end

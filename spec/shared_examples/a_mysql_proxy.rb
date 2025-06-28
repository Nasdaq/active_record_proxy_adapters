# frozen_string_literal: true

require "shared_examples/a_proxied_method"
require "shared_examples/a_transaction_block_proxy_bypass"

RSpec.shared_examples "a MySQL proxy" do
  attr_reader :primary_adapter

  let(:replica_pool) { nil }
  let(:primary_pool) { nil }
  let(:adapter_class) { nil }
  let(:model_class) { nil }

  let(:truncate_database) { nil }

  around do |example|
    primary_pool.with_connection do |connection|
      @primary_adapter = connection

      example.run

      @primary_adapter = nil
    end

    truncate_database
  end

  def create_dummy_user
    primary_adapter.execute_unproxied <<~SQL.strip
      INSERT INTO users (name, email)
      VALUES ('John Doe', 'john.doe@example.com');
    SQL
  end

  it_behaves_like "a transaction block proxy bypass"

  describe "#execute" do
    it_behaves_like "a proxied method", :execute
  end

  describe "#exec_query" do
    it_behaves_like "a proxied method", :exec_query
  end

  if TestHelper.active_record_context.active_record_v8_0_or_greater?
    describe "#internal_exec_query" do
      it_behaves_like "a proxied method", :internal_exec_query
    end
  end
end

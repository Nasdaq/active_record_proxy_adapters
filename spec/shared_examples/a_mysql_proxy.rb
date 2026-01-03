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

  describe "#exec_delete" do
    include_context "a proxied method setup" do
      let(:method_name) { :exec_delete }
    end

    it_behaves_like "a SQL write statement" do
      let(:sql) do
        <<~SQL.strip
          DELETE FROM users
          WHERE  email = 'john.doe@example.com';
        SQL
      end
    end
  end

  describe "#exec_insert" do
    it_behaves_like "a proxied method", :exec_insert do
      before do
        # exec_insert in trilogy does not adhere to the standard method signature. These /exec_/ methods will be
        # deprecated in future rails releases so we are skipping tests for now.
        if adapter_class == ActiveRecord::ConnectionAdapters::TrilogyAdapter
          skip "trilogy adapter does not support standard exec_insert signature"
        end
      end
    end
  end

  describe "#exec_query" do
    include_context "a proxied method setup" do
      let(:method_name) { :exec_query }
    end

    it_behaves_like "a proxied method", :exec_query
  end

  describe "#exec_update" do
    include_context "a proxied method setup" do
      let(:method_name) { :exec_update }
    end

    it_behaves_like "a SQL write statement" do
      let(:sql) do
        <<~SQL.strip
          UPDATE users
          SET    name  = 'Johnny Doe'
          WHERE  email = 'john.doe@example.com';
        SQL
      end
    end
  end

  describe "#execute" do
    it_behaves_like "a proxied method", :execute do
      it_behaves_like "a SQL pattern matching timeout"
    end
  end

  describe "#select" do
    it_behaves_like "a proxied method", :select
  end
end

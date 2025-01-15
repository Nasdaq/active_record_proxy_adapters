# frozen_string_literal: true

require_relative "shared_examples/a_proxied_method"

RSpec.describe ActiveRecordProxyAdapters::PostgreSQLProxy do # rubocop:disable RSpec/SpecFilePathFormat
  attr_reader :primary_adapter

  let(:replica_pool) { TestHelper.replica_pool }
  let(:primary_pool) { TestHelper.primary_pool }
  let(:adapter_class) { ActiveRecord::ConnectionAdapters::PostgreSQLAdapter }
  let(:model_class) { TestHelper::PostgreSQLRecord }

  around do |example|
    primary_pool.with_connection do |connection|
      @primary_adapter = connection

      example.run

      @primary_adapter = nil
    end

    TestHelper.truncate_database
  end

  def create_dummy_user
    primary_adapter.execute_unproxied <<~SQL.strip
      INSERT INTO users (name, email)
      VALUES ('John Doe', 'john.doe@example.com');
    SQL
  end

  describe "#execute" do
    it_behaves_like "a_proxied_method", :execute do
      subject(:run_test) { proxy.execute(sql) }
    end
  end

  describe "#exec_query" do
    it_behaves_like "a_proxied_method", :exec_query do
      subject(:run_test) { proxy.exec_query(sql) }
    end
  end

  unless TestHelper.active_record_context.active_record_v8_0_or_greater?
    describe "#exec_no_cache" do
      it_behaves_like "a_proxied_method", :exec_no_cache do
        subject(:run_test) do
          if ActiveRecord.version < Gem::Version.new("7.1")
            proxy.exec_no_cache(sql, "SQL", [])
          else
            proxy.exec_no_cache(sql, "SQL", [], async: false, allow_retry: false, materialize_transactions: false)
          end
        end

        let(:read_only_error_class) { ActiveRecord::StatementInvalid }
      end
    end

    describe "#exec_cache" do
      it_behaves_like "a_proxied_method", :exec_cache do
        subject(:run_test) do
          if ActiveRecord.version < Gem::Version.new("7.1")
            proxy.exec_cache(sql, "SQL", [])
          else
            proxy.exec_cache(sql, "SQL", [], async: false, allow_retry: false, materialize_transactions: false)
          end
        end

        let(:read_only_error_class) { ActiveRecord::StatementInvalid }
      end
    end
  end
end

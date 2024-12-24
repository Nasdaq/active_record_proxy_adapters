# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::PostgreSQLProxy do # rubocop:disable RSpec/SpecFilePathFormat
  attr_reader :primary_adapter

  let(:replica_pool) { TestHelper.replica_pool }
  let(:primary_pool) { TestHelper.primary_pool }

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

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  shared_examples_for "a_proxied_method" do |method_name|
    subject(:run_test) { proxy.public_send(method_name, sql) }

    let(:proxy) { described_class.new(primary_adapter) }
    let(:read_only_error_class) { ActiveRecord::ReadOnlyError }
    let(:model_class) { TestHelper::PostgreSQLRecord }

    context "when query is a select statement" do
      let(:sql) { "SELECT * from users" }

      it "checks out a connection from the replica pool" do
        allow(replica_pool).to receive(:checkout).and_call_original

        run_test

        expect(replica_pool).to have_received(:checkout).once
      end

      it "checks replica connection back in to the pool" do
        conn = instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, method_name => nil)
        allow(replica_pool).to receive(:checkout).and_return(conn)
        allow(replica_pool).to receive(:checkin)

        run_test

        expect(replica_pool).to have_received(:checkin).with(conn).once
      end

      context "when a transaction is open" do
        it "reroutes query to the primary" do
          allow(primary_adapter).to receive(:"#{method_name}_unproxied").and_call_original

          primary_adapter.transaction { run_test }

          expect(primary_adapter).to have_received(:"#{method_name}_unproxied").with(sql, any_args).once
        end

        it "does not checkout a connection from the replica pool" do
          allow(replica_pool).to receive(:checkout).and_call_original

          primary_adapter.transaction { run_test }

          expect(replica_pool).not_to have_received(:checkout)
        end
      end

      context "when sticking to primary connection" do
        it "reroutes query to the primary" do
          allow(primary_adapter).to receive(:"#{method_name}_unproxied").and_call_original

          model_class.connected_to(role: TestHelper.writing_role) { run_test }

          expect(primary_adapter).to have_received(:"#{method_name}_unproxied").with(sql, any_args).once
        end

        it "does not checkout a connection from the replica pool" do
          allow(replica_pool).to receive(:checkout).and_call_original

          model_class.connected_to(role: TestHelper.writing_role) { run_test }

          expect(replica_pool).not_to have_received(:checkout)
        end
      end
    end

    shared_examples_for "a SQL write statement" do
      it "does not checkout a connection from replica pool" do
        allow(replica_pool).to receive(:checkout).and_call_original

        run_test

        expect(replica_pool).not_to have_received(:checkout)
      end

      it "sends query to primary connection" do
        allow(primary_adapter).to receive(:"#{method_name}_unproxied").and_call_original

        run_test

        expect(primary_adapter).to have_received(:"#{method_name}_unproxied").with(sql, any_args).once
      end

      context "when sticking to replica" do
        it "raises database error" do
          expect do
            model_class.connected_to(role: TestHelper.reading_role) { run_test }
          end.to raise_error(read_only_error_class)
        end
      end
    end

    context "when query is an INSERT statement" do
      it_behaves_like "a SQL write statement" do
        let(:sql) do
          <<~SQL.strip
            INSERT INTO users (name, email)
            VALUES ('John Doe', 'john.doe@example.com');
          SQL
        end
      end
    end

    context "when query is an UPDATE statement" do
      before { create_dummy_user }

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

    context "when query is a DELETE statement" do
      before { create_dummy_user }

      it_behaves_like "a SQL write statement" do
        let(:sql) do
          <<~SQL.strip
            DELETE FROM users
            WHERE  email = 'john.doe@example.com';
          SQL
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

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

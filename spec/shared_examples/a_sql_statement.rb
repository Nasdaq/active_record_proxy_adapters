# frozen_string_literal: true

require "shared_contexts/a_proxied_method_setup"

RSpec.shared_examples_for "a SQL read statement" do
  it "leases a connection from the replica pool" do
    allow(replica_pool).to receive(:lease_connection).and_call_original

    run_test

    expect(replica_pool).to have_received(:lease_connection).once
  end

  it "uses the leased replica connection" do
    conn = instance_double(adapter_class, method_name => nil, pool: replica_pool)
    allow(replica_pool).to receive(:lease_connection).and_return(conn)

    run_test

    expect(conn).to have_received(method_name).once
  end

  context "when a transaction is open" do
    it "reroutes query to the primary" do
      allow(primary_adapter).to receive(:"#{method_name}_unproxied").and_call_original

      primary_adapter.transaction { run_test }

      expect(primary_adapter).to have_received(:"#{method_name}_unproxied").with(sql, any_args).once
    end

    it "does not checkout a connection from the replica pool" do
      allow(replica_pool).to receive(:lease_connection).and_call_original

      primary_adapter.transaction { run_test }

      expect(replica_pool).not_to have_received(:lease_connection)
    end
  end

  context "when sticking to primary connection" do
    it "reroutes query to the primary" do
      allow(primary_adapter).to receive(:"#{method_name}_unproxied").and_call_original

      model_class.connected_to(role: TestHelper.writing_role) { run_test }

      expect(primary_adapter).to have_received(:"#{method_name}_unproxied").with(sql, any_args).once
    end

    it "does not checkout a connection from the replica pool" do
      allow(replica_pool).to receive(:lease_connection).and_call_original

      model_class.connected_to(role: TestHelper.writing_role) { run_test }

      expect(replica_pool).not_to have_received(:lease_connection)
    end
  end
end

RSpec.shared_examples_for "a SQL write statement" do
  it "does not checkout a connection from replica pool" do
    allow(replica_pool).to receive(:lease_connection).and_call_original

    run_test

    expect(replica_pool).not_to have_received(:lease_connection)
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

# frozen_string_literal: true

require "shared_contexts/a_proxied_method_setup"

RSpec.shared_examples_for "a SQL read statement" do
  it "checks out a connection from the replica pool" do
    allow(replica_pool).to receive(:checkout).and_call_original

    run_test

    expect(replica_pool).to have_received(:checkout).once
  end

  it "checks replica connection back in to the pool" do
    conn = instance_double(adapter_class, method_name => nil)
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

RSpec.shared_examples_for "a SQL write statement" do
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

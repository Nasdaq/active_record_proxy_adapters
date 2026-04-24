# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::PrimaryReplicaProxy do
  describe "#connection_for" do
    # In Rails' system tests, ActiveRecord::TestFixtures#setup_shared_connection_pool
    # reassigns the :reading role's pool_config to the :writing pool_config on every
    # transactional-fixture test's before_setup. Because PrimaryReplicaProxy resolves
    # `replica_pool` on every call via retrieve_connection_pool(..., role: :reading),
    # a swap that occurs between the initial checkout (in #checkout_replica_connection)
    # and the ensure-block checkin causes the replica connection to be checked into
    # the wrong (primary) pool, where a later ConnectionPool#pin_connection! picks it
    # up as the fixture-transaction connection and every subsequent write on the
    # primary class raises ActiveRecord::ReadOnlyError.
    #
    # This spec exercises that race deterministically: we stub `replica_pool` on the
    # proxy to return the real replica pool on the checkout call and the primary pool
    # on the ensure-block call, mirroring what the handler does when
    # setup_shared_connection_pool runs mid-SELECT. After the query completes, the
    # connection must still land in its original (replica) pool, not the primary pool.
    context "when the :reading pool_config is reassigned between checkout and the ensure-block checkin" do
      subject(:run_query) { proxy.execute(sql) }

      let(:primary_pool) { TestHelper.sqlite3_primary_pool }
      let(:replica_pool) { TestHelper.sqlite3_replica_pool }
      let(:proxy) { ActiveRecordProxyAdapters::SQLite3Proxy.new(primary_adapter) }
      let(:sql) { "SELECT 1" }

      around do |example|
        primary_pool.with_connection do |connection|
          @primary_adapter = connection
          example.run
          @primary_adapter = nil
        end
      end

      attr_reader :primary_adapter

      def primary_available_connections
        primary_pool.instance_variable_get(:@available).instance_variable_get(:@queue)
      end

      before do
        # Simulate `setup_shared_connection_pool` firing between the proxy's
        # checkout_replica_connection and the ensure-block `replica_pool.checkin`.
        # The proxy calls `replica_pool` more than once per `connection_for` — we
        # return the real replica pool for the checkout-side calls and the primary
        # pool for the final checkin call, which is exactly what a mid-flight
        # pool_config swap produces.
        call_count = 0
        allow(proxy).to receive(:replica_pool).and_wrap_original do |original, *args, **kwargs|
          call_count += 1
          last_call = call_count >= 3
          last_call ? primary_pool : original.call(*args, **kwargs)
        end
      end

      it "does not leave the replica connection in the primary pool" do
        run_query

        leaked = primary_available_connections.find { |c| c.respond_to?(:replica?) && c.replica? }

        expect(leaked).to be_nil, "replica adapter leaked into the primary pool (#{leaked.inspect})"
      end
    end
  end
end

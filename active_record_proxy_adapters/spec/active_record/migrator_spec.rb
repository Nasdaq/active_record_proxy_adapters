# frozen_string_literal: true

RSpec.describe ActiveRecord::Migrator do
  shared_examples_for "pending_migrations" do
    subject(:pending_migrations) do
      described_class.new(direction, migration_list, schema_migration, internal_metadata).pending_migrations
    end

    attr_reader :pool, :schema_migration, :internal_metadata

    around do |example|
      TestHelper.with_temporary_pool(connection_class) do |pool, schema_migration, internal_metadata|
        @pool = pool
        @schema_migration = schema_migration
        @internal_metadata = internal_metadata
        ActiveRecord::Base.establish_connection(connection_class.connection_db_config)
        example.run
      end
    ensure
      @pool = nil
      @schema_migration = nil
      @internal_metadata = nil
    end

    let(:migration_list) { [ActiveRecord::Migration.new("foo", 1), ActiveRecord::Migration.new("bar", 2)] }

    context "when direction is up" do
      let(:direction) { :up }

      it "does not crash" do
        expect { pending_migrations }.not_to raise_error
      end
    end

    context "when direction is down" do
      let(:direction) { :down }

      it "does not crash" do
        expect { pending_migrations }.not_to raise_error
      end
    end
  end

  describe "#pending_migrations" do
    context "when adapter is PostgreSQLProxy" do
      it_behaves_like "pending_migrations" do
        let(:connection_class) { TestHelper::PostgreSQLRecord }
      end
    end
  end
end

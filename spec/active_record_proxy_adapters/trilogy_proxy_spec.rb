# frozen_string_literal: true

require "shared_examples/a_mysql_proxy"

RSpec.describe ActiveRecordProxyAdapters::TrilogyProxy do
  it_behaves_like "a MySQL proxy" do
    let(:replica_pool) { TestHelper.trilogy_replica_pool }
    let(:primary_pool) { TestHelper.trilogy_primary_pool }
    let(:adapter_class) { ActiveRecord::ConnectionAdapters::TrilogyAdapter }
    let(:model_class) { TestHelper::TrilogyRecord }
    let(:truncate_database) { TestHelper.truncate_trilogy_database }
  end
end

# frozen_string_literal: true

require "shared_examples/a_mysql_proxy"

RSpec.describe ActiveRecordProxyAdapters::Mysql2Proxy do
  it_behaves_like "a MySQL proxy" do
    let(:replica_pool) { TestHelper.mysql2_replica_pool }
    let(:primary_pool) { TestHelper.mysql2_primary_pool }
    let(:adapter_class) { ActiveRecord::ConnectionAdapters::Mysql2Adapter }
    let(:model_class) { TestHelper::Mysql2Record }
    let(:truncate_database) { TestHelper.truncate_mysql2_database }
  end
end

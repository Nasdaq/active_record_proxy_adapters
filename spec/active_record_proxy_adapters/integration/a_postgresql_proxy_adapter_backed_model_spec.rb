# frozen_string_literal: true

require "shared_examples/a_proxied_model"

RSpec.describe "A PostgreSQLProxyAdapter-backed model", :integration do # rubocop:disable RSpec/DescribeClass
  it_behaves_like "a proxied model" do
    let(:model_class) { TestHelper::PostgreSQLRecord }
    let(:database_identifier) { :postgresql }
    let(:log_subscriber_primary_prefix) { "postgresql_primary" }
    let(:log_subscriber_replica_prefix) { "postgresql_replica" }
    let(:truncate_database) { TestHelper.truncate_postgresql_database }
  end
end

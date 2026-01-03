# frozen_string_literal: true

require "shared_examples/a_proxied_model"

RSpec.describe "A SQLite3ProxyAdapter-backed model", :integration do # rubocop:disable RSpec/DescribeClass
  it_behaves_like "a proxied model" do
    let(:model_class) { TestHelper::SQLite3Record }
    let(:database_identifier) { :sqlite3 }
    let(:log_subscriber_primary_prefix) { "sqlite3_primary" }
    let(:log_subscriber_replica_prefix) { "sqlite3_replica" }
    let(:truncate_database) { TestHelper.truncate_sqlite3_database }
  end
end

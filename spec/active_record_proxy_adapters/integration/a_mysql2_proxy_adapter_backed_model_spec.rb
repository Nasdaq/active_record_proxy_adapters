# frozen_string_literal: true

require "shared_examples/a_proxied_model"

RSpec.describe "A Mysql2ProxyAdapter-backed model", :integration do # rubocop:disable RSpec/DescribeClass
  it_behaves_like "a proxied model" do
    let(:model_class) { TestHelper::Mysql2Record }
    let(:database_identifier) { :mysql2 }
    let(:log_subscriber_primary_prefix) { "mysql2_primary" }
    let(:log_subscriber_replica_prefix) { "mysql2_replica" }
    let(:truncate_database) { TestHelper.truncate_mysql2_database }
  end
end

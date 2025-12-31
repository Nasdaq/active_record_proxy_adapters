# frozen_string_literal: true

require "shared_examples/a_proxied_model"

RSpec.describe "A TrilogyProxyAdapter-backed model", :integration do # rubocop:disable RSpec/DescribeClass
  it_behaves_like "a proxied model" do
    let(:model_class) { TestHelper::TrilogyRecord }
    let(:database_identifier) { :trilogy }
    let(:log_subscriber_primary_prefix) { "trilogy_primary" }
    let(:log_subscriber_replica_prefix) { "trilogy_replica" }
    let(:truncate_database) { TestHelper.truncate_trilogy_database }
  end
end

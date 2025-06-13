# frozen_string_literal: true

RSpec.describe ActiveRecordProxyAdapters::CacheConfiguration do
  describe "#bust" do
    subject(:bust) { cache.bust }

    let(:cache) { described_class.new }

    before do
      cache.store      = ActiveSupport::Cache::MemoryStore.new
      cache.key_prefix = "test_prefix_"

      cache.store.write("test_prefix_key1", "value1")
      cache.store.write("test_prefix_key2", "value2")
      cache.store.write("other_prefix_key", "value3")
    end

    it "deletes all keys with the specified prefix while keeping other keys intact" do
      expect { bust }
        .to  change     { cache.store.exist?("test_prefix_key1") }.from(true).to(false)
        .and change     { cache.store.exist?("test_prefix_key2") }.from(true).to(false)
        .and(not_change { cache.store.exist?("other_prefix_key") })
    end
  end
end

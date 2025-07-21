# frozen_string_literal: true

require "active_record_proxy_adapters/synchronizable_configuration"

module ActiveRecordProxyAdapters
  class CacheConfiguration # rubocop:disable Style/Documentation
    include SynchronizableConfiguration

    # Sets the cache store to use for caching SQL statements.
    #
    # @param store [ActiveSupport::Cache::Store] The cache store to use for caching SQL statements.
    #   Defaults to ActiveSupport::Cache::NullStore, which does not cache anything.
    #   Thread safe.
    # @return [ActiveSupport::Cache::Store] The cache store to use for caching SQL statements.
    #   Defaults to ActiveSupport::Cache::NullStore, which does not cache anything.
    #   Thread safe.
    attr_reader :store

    # @return [String] The prefix to use for cache keys. Defaults to "arpa_".
    attr_reader :key_prefix

    # @return [Proc] A proc that takes an SQL statement and returns a cache key.
    #   Defaults to a SHA2 hexdigest of the SQL statement.
    attr_reader :key_builder

    def initialize(lock = Monitor.new)
      @lock            = lock
      self.store       = ActiveSupport::Cache::NullStore.new
      self.key_prefix  = "arpa_"
      self.key_builder = ->(sql) { Digest::SHA2.hexdigest(sql) }
    end

    def store=(store)
      synchronize_update(:"cache.store", from: @store, to: store) do
        @store = store
      end
    end

    def key_prefix=(key_prefix)
      synchronize_update(:"cache.key_prefix", from: @key_prefix, to: key_prefix) do
        @key_prefix = key_prefix
      end
    end

    def key_builder=(key_builder)
      synchronize_update(:"cache.key_builder", from: @key_builder, to: key_builder) do
        @key_builder = key_builder
      end
    end

    def bust
      store.delete_matched("#{key_prefix}*")
    end
  end
end

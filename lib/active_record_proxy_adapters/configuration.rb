# frozen_string_literal: true

require "active_record_proxy_adapters/cache_configuration"
require "active_record_proxy_adapters/context"
require "active_record_proxy_adapters/database_configuration"
require "active_record_proxy_adapters/synchronizable_configuration"
require "active_support/core_ext/integer/time"

module ActiveRecordProxyAdapters
  # Provides a global configuration object to configure how the proxy should behave.
  class Configuration
    include SynchronizableConfiguration

    DEFAULT_DATABASE_NAME = :primary

    # @return [Class] The context that is used to store the current request's state.
    attr_reader :context_store

    def initialize
      @lock = Monitor.new

      self.cache_configuration = CacheConfiguration.new(@lock)
      self.context_store       = ActiveRecordProxyAdapters::Context
      @database_configurations = {}
    end

    def log_subscriber_primary_prefix=(prefix)
      default_database_config.log_subscriber_primary_prefix = prefix
    end

    def log_subscriber_primary_prefix
      default_database_config.log_subscriber_primary_prefix
    end

    def log_subscriber_replica_prefix=(prefix)
      default_database_config.log_subscriber_replica_prefix = prefix
    end

    def log_subscriber_replica_prefix
      default_database_config.log_subscriber_replica_prefix
    end

    def proxy_delay
      default_database_config.proxy_delay
    end

    def proxy_delay=(proxy_delay)
      default_database_config.proxy_delay = proxy_delay
    end

    def checkout_timeout
      default_database_config.checkout_timeout
    end

    def checkout_timeout=(checkout_timeout)
      default_database_config.checkout_timeout = checkout_timeout
    end

    def database(database_name)
      key = database_name.to_s
      lock.synchronize { @database_configurations[key] ||= DatabaseConfiguration.new }

      block_given? ? yield(database_configurations[key]) : database_configurations[key]
    end

    def cache
      block_given? ? yield(cache_configuration) : cache_configuration
    end

    private

    attr_reader :cache_configuration, :database_configurations, :lock

    def default_database_config
      database(DEFAULT_DATABASE_NAME)
    end

    def cache_configuration=(cache_configuration)
      synchronize_update(:cache_configuration, from: @cache_configuration, to: cache_configuration) do
        @cache_configuration = cache_configuration
      end
    end

    def context_store=(context_store)
      synchronize_update(:context_store, from: @context_store, to: context_store) do
        @context_store = context_store
      end
    end
  end
end

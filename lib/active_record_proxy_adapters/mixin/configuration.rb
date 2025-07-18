# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require "active_record_proxy_adapters/synchronizable_configuration"
require "active_record_proxy_adapters/cache_configuration"
require "active_record_proxy_adapters/context"

module ActiveRecordProxyAdapters
  module Mixin
    # Provides helpers to access to reduce boilerplate while retrieving configuration properties.
    module Configuration
      # Helper to retrieve the proxy delay from the configuration stored in
      # {ActiveRecordProxyAdapters::Configuration#proxy_delay}.
      # @return [ActiveSupport::Duration]
      def proxy_delay
        proxy_config.proxy_delay
      end

      # Helper to retrieve the checkout timeout from the configuration stored in
      # {ActiveRecordProxyAdapters::Configuration#checkout_timeout}.
      # @return [ActiveSupport::Duration]
      def checkout_timeout
        proxy_config.checkout_timeout
      end

      # Helper to retrieve the context store class from the configuration stored in
      # {ActiveRecordProxyAdapters::Configuration#context_store}.
      # @return [Class]
      def context_store
        proxy_config.context_store
      end

      # Helper to retrieve the cache store from the configuration stored in
      # {ActiveRecordProxyAdapters::CacheConfiguration#store}.
      # @return [ActiveSupport::Cache::Store]
      def cache_store
        cache_config.store
      end

      # Helper to retrieve the cache key prefix from the configuration stored in
      # {ActiveRecordProxyAdapters::CacheConfiguration#key_prefix}.
      # It uses the key builder to generate a cache key for the given SQL string, prepended with the key prefix.
      # @return [String]
      def cache_key_for(sql_string)
        cache_config.key_builder.call(sql_string).prepend(cache_config.key_prefix)
      end

      # @!visibility private
      def cache_config
        proxy_config.cache
      end

      # @!visibility private
      def proxy_config
        ActiveRecordProxyAdapters.config
      end
    end
  end
end

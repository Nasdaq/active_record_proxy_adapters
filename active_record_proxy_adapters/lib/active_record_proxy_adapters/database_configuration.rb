# frozen_string_literal: true

require "active_support/core_ext/integer/time"
require "active_record_proxy_adapters/synchronizable_configuration"
require "active_record_proxy_adapters/cache_configuration"
require "active_record_proxy_adapters/context"

module ActiveRecordProxyAdapters
  # Provides a global configuration object to configure how the proxy should behave.
  class DatabaseConfiguration
    include SynchronizableConfiguration

    PROXY_DELAY      = 2.seconds.freeze
    CHECKOUT_TIMEOUT = 2.seconds.freeze
    DEFAULT_PREFIX   = proc do |event|
      connection = event.payload[:connection]

      connection.pool.try(:db_config).try(:name) || connection.class::ADAPTER_NAME
    end

    # @return [ActiveSupport::Duration] How long the proxy should reroute all read requests to the primary database
    #   since the latest write. Defaults to PROXY_DELAY. Thread safe.
    attr_reader :proxy_delay
    # @return [ActiveSupport::Duration] How long the proxy should wait for a connection from the replica pool.
    #   Defaults to CHECKOUT_TIMEOUT. Thread safe.
    attr_reader :checkout_timeout

    # @return [Proc] Prefix for the log subscriber when the database is used. Thread safe.
    attr_reader :log_subscriber_prefix

    def initialize
      @lock                      = Monitor.new
      self.proxy_delay           = PROXY_DELAY
      self.checkout_timeout      = CHECKOUT_TIMEOUT
      self.log_subscriber_prefix = DEFAULT_PREFIX
    end

    def proxy_delay=(proxy_delay)
      synchronize_update(:proxy_delay, from: @proxy_delay, to: proxy_delay) do
        @proxy_delay = proxy_delay
      end
    end

    def checkout_timeout=(checkout_timeout)
      synchronize_update(:checkout_timeout, from: @checkout_timeout, to: checkout_timeout) do
        @checkout_timeout = checkout_timeout
      end
    end

    def log_subscriber_prefix=(prefix)
      prefix_proc = prefix.is_a?(Proc) ? prefix : proc { prefix.to_s }

      synchronize_update(:log_subscriber_prefix, from: @log_subscriber_prefix, to: prefix_proc) do
        @log_subscriber_prefix = prefix_proc
      end
    end

    private

    attr_reader :lock
  end
end

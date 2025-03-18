# frozen_string_literal: true

require "active_support/core_ext/integer/time"

module ActiveRecordProxyAdapters
  # Provides a global configuration object to configure how the proxy should behave.
  class Configuration
    PROXY_DELAY                   = 2.seconds.freeze
    CHECKOUT_TIMEOUT              = 2.seconds.freeze
    LOG_SUBSCRIBER_PRIMARY_PREFIX = proc { |event| "#{event.payload[:connection].class::ADAPTER_NAME} Primary" }.freeze
    LOG_SUBSCRIBER_REPLICA_PREFIX = proc { |event| "#{event.payload[:connection].class::ADAPTER_NAME} Replica" }.freeze

    # @return [ActiveSupport::Duration] How long the proxy should reroute all read requests to the primary database
    #   since the latest write. Defaults to PROXY_DELAY. Thread safe.
    attr_reader :proxy_delay
    # @return [ActiveSupport::Duration] How long the proxy should wait for a connection from the replica pool.
    #   Defaults to CHECKOUT_TIMEOUT. Thread safe.
    attr_reader :checkout_timeout

    # @return [Proc] Prefix for the log subscriber when the primary database is used. Thread safe.
    attr_reader :log_subscriber_primary_prefix

    # @return [Proc] Prefix for the log subscriber when the replica database is used. Thread safe.
    attr_reader :log_subscriber_replica_prefix

    def initialize
      @lock = Monitor.new

      self.proxy_delay                   = PROXY_DELAY
      self.checkout_timeout              = CHECKOUT_TIMEOUT
      self.log_subscriber_primary_prefix = LOG_SUBSCRIBER_PRIMARY_PREFIX
      self.log_subscriber_replica_prefix = LOG_SUBSCRIBER_REPLICA_PREFIX
    end

    def log_subscriber_primary_prefix=(prefix)
      prefix_proc = prefix.is_a?(Proc) ? prefix : proc { prefix.to_s }

      synchronize_update(:log_subscriber_primary_prefix, from: @log_subscriber_primary_prefix, to: prefix_proc) do
        @log_subscriber_primary_prefix = prefix_proc
      end
    end

    def log_subscriber_replica_prefix=(prefix)
      prefix_proc = prefix.is_a?(Proc) ? prefix : proc { prefix.to_s }

      synchronize_update(:log_subscriber_replica_prefix, from: @log_subscriber_replica_prefix, to: prefix_proc) do
        @log_subscriber_replica_prefix = prefix_proc
      end
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

    private

    def synchronize_update(attribute, from:, to:, &block)
      ActiveSupport::Notifications.instrument(
        "active_record_proxy_adapters.configuration_update",
        attribute:,
        who: Thread.current,
        from:,
        to:
      ) do
        @lock.synchronize(&block)
      end
    end
  end
end

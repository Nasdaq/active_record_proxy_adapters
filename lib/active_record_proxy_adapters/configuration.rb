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
    #   since the latest write. Defaults to PROXY_DELAY.
    attr_accessor :proxy_delay
    # @return [ActiveSupport::Duration] How long the proxy should wait for a connection from the replica pool.
    #   Defaults to CHECKOUT_TIMEOUT.
    attr_accessor :checkout_timeout

    # @return [Proc] Prefix for the log subscriber when the primary database is used.
    attr_reader :log_subscriber_primary_prefix

    # @return [Proc] Prefix for the log subscriber when the replica database is used.
    attr_reader :log_subscriber_replica_prefix

    def initialize
      self.proxy_delay                   = PROXY_DELAY
      self.checkout_timeout              = CHECKOUT_TIMEOUT
      self.log_subscriber_primary_prefix = LOG_SUBSCRIBER_PRIMARY_PREFIX
      self.log_subscriber_replica_prefix = LOG_SUBSCRIBER_REPLICA_PREFIX
    end

    def log_subscriber_primary_prefix=(prefix)
      @log_subscriber_primary_prefix = prefix.is_a?(Proc) ? prefix : proc { prefix.to_s }
    end

    def log_subscriber_replica_prefix=(prefix)
      @log_subscriber_replica_prefix = prefix.is_a?(Proc) ? prefix : proc { prefix.to_s }
    end
  end
end

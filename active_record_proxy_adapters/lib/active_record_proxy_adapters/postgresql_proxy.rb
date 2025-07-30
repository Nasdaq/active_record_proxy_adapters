# frozen_string_literal: true

require "active_record_proxy_adapters/primary_replica_proxy"
require "active_record_proxy_adapters/active_record_context"

module ActiveRecordProxyAdapters
  # Proxy to the original PostgreSQLAdapter, allowing the use of the ActiveRecordProxyAdapters::PrimaryReplicaProxy.
  class PostgreSQLProxy < PrimaryReplicaProxy
    # ActiveRecord::PostgreSQLAdapter methods that should be proxied.
    hijack_method :exec_no_cache, :exec_cache unless ActiveRecordContext.active_record_v8_0_or_greater?
  end
end

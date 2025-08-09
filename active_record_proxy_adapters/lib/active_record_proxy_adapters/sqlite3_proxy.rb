# frozen_string_literal: true

require "active_record_proxy_adapters/primary_replica_proxy"
require "active_record_proxy_adapters/active_record_context"

module ActiveRecordProxyAdapters
  # Proxy to the original SQLite3Adapter, allowing the use of the ActiveRecordProxyAdapters::PrimaryReplicaProxy.
  class SQLite3Proxy < PrimaryReplicaProxy
  end
end

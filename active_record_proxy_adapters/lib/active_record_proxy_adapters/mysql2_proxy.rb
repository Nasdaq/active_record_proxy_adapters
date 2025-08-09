# frozen_string_literal: true

require "active_record_proxy_adapters/primary_replica_proxy"

module ActiveRecordProxyAdapters
  # Proxy to the original Mysql2Adapter, allowing the use of the ActiveRecordProxyAdapters::PrimaryReplicaProxy.
  class Mysql2Proxy < PrimaryReplicaProxy
  end
end

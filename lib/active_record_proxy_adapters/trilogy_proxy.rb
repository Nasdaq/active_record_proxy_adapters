# frozen_string_literal: true

require "active_record_proxy_adapters/mysql2_proxy"

module ActiveRecordProxyAdapters
  # Proxy to the Mysql2Proxy, allowing the use of the ActiveRecordProxyAdapters::PrimaryReplicaProxy.
  class TrilogyProxy < Mysql2Proxy
    hijack_method :exec_insert
  end
end

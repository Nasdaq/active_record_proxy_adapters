# frozen_string_literal: true

require "active_record/tasks/mysql2_proxy_database_tasks"
require "active_record/connection_adapters/mysql2_adapter"
require "active_record_proxy_adapters/active_record_context"
require "active_record_proxy_adapters/hijackable"
require "active_record_proxy_adapters/mysql2_proxy"

module ActiveRecord
  module ConnectionAdapters
    # This adapter is a proxy to the original Mysql2Adapter, allowing the use of the
    # ActiveRecordProxyAdapters::PrimaryReplicaProxy.
    class Mysql2ProxyAdapter < Mysql2Adapter
      include ActiveRecordProxyAdapters::Hijackable

      ADAPTER_NAME = "Mysql2Proxy"

      delegate_to_proxy :execute, :exec_query

      def initialize(...)
        @proxy = ActiveRecordProxyAdapters::Mysql2Proxy.new(self)

        super
      end

      private

      attr_reader :proxy
    end
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "mysql2_proxy",
    "ActiveRecord::ConnectionAdapters::Mysql2ProxyAdapter",
    "active_record/connection_adapters/mysql2_proxy_adapter"
  )
end

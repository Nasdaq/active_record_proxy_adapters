# frozen_string_literal: true

require "active_record/tasks/sqlite3_proxy_database_tasks"
require "active_record/connection_adapters/sqlite3_adapter"
require "active_record_proxy_adapters/active_record_context"
require "active_record_proxy_adapters/hijackable"
require "active_record_proxy_adapters/sqlite3_proxy"

module ActiveRecord
  module ConnectionAdapters
    # This adapter is a proxy to the original SQLite3Adapter, allowing the use of the
    # ActiveRecordProxyAdapters::PrimaryReplicaProxy.
    class SQLite3ProxyAdapter < SQLite3Adapter
      include ActiveRecordProxyAdapters::Hijackable

      ADAPTER_NAME = "SQLite3Proxy"

      delegate_to_proxy(*ActiveRecordProxyAdapters::ActiveRecordContext.hijackable_methods)

      def initialize(...)
        @proxy = ActiveRecordProxyAdapters::SQLite3Proxy.new(self)

        super
      end

      private

      attr_reader :proxy
    end
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "sqlite3_proxy",
    "ActiveRecord::ConnectionAdapters::SQLite3ProxyAdapter",
    "active_record/connection_adapters/sqlite3_proxy_adapter"
  )
end

ActiveSupport.run_load_hooks(:active_record_sqlite3proxyadapter,
                             ActiveRecord::ConnectionAdapters::SQLite3ProxyAdapter)

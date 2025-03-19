# frozen_string_literal: true

require "active_record/tasks/postgresql_proxy_database_tasks"
require "active_record/connection_adapters/postgresql_adapter"
require "active_record_proxy_adapters/active_record_context"
require "active_record_proxy_adapters/hijackable"
require "active_record_proxy_adapters/postgresql_proxy"

module ActiveRecord
  module ConnectionAdapters
    # This adapter is a proxy to the original PostgreSQLAdapter, allowing the use of the
    # ActiveRecordProxyAdapters::PrimaryReplicaProxy.
    class PostgreSQLProxyAdapter < PostgreSQLAdapter
      include ActiveRecordProxyAdapters::Hijackable

      ADAPTER_NAME = "PostgreSQLProxy"

      delegate_to_proxy(*ActiveRecordProxyAdapters::ActiveRecordContext.hijackable_methods)

      unless ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v8_0_or_greater?
        delegate_to_proxy :exec_no_cache, :exec_cache
      end

      def initialize(...)
        @proxy = ActiveRecordProxyAdapters::PostgreSQLProxy.new(self)

        super
      end

      private

      attr_reader :proxy
    end
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "postgresql_proxy",
    "ActiveRecord::ConnectionAdapters::PostgreSQLProxyAdapter",
    "active_record/connection_adapters/postgresql_proxy_adapter"
  )
end

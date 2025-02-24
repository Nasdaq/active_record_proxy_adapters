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
      ActiveRecord::Type.register(:immutable_string, adapter: :mysql2_proxy) do |_, **args|
        Type::ImmutableString.new(true: "1", false: "0", **args)
      end

      ActiveRecord::Type.register(:string, adapter: :mysql2_proxy) do |_, **args|
        Type::String.new(true: "1", false: "0", **args)
      end

      ActiveRecord::Type.register(:unsigned_integer, Type::UnsignedInteger, adapter: :mysql2_proxy)
    end

    ActiveSupport.run_load_hooks(:active_record_mysql2proxyadapter, Mysql2ProxyAdapter)
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "mysql2_proxy",
    "ActiveRecord::ConnectionAdapters::Mysql2ProxyAdapter",
    "active_record/connection_adapters/mysql2_proxy_adapter"
  )
end

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

      delegate_to_proxy :execute, :exec_query

      unless ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v8_0_or_greater?
        delegate_to_proxy :exec_no_cache, :exec_cache
      end

      def initialize(...)
        @proxy = ActiveRecordProxyAdapters::PostgreSQLProxy.new(self)

        super
      end

      private

      attr_reader :proxy
      ActiveRecord::Type.add_modifier({ array: true }, OID::Array, adapter: :postgresql_proxy)
      ActiveRecord::Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:bit, OID::Bit, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:bit_varying, OID::BitVarying, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:binary, OID::Bytea, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:cidr, OID::Cidr, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:date, OID::Date, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:datetime, OID::DateTime, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:decimal, OID::Decimal, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:enum, OID::Enum, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:hstore, OID::Hstore, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:inet, OID::Inet, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:interval, OID::Interval, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:jsonb, OID::Jsonb, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:money, OID::Money, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:point, OID::Point, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:legacy_point, OID::LegacyPoint, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:uuid, OID::Uuid, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:vector, OID::Vector, adapter: :postgresql_proxy)
      ActiveRecord::Type.register(:xml, OID::Xml, adapter: :postgresql_proxy)
    end
    ActiveSupport.run_load_hooks(:active_record_postgresqlproxyadapter, PostgreSQLProxyAdapter)
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "postgresql_proxy",
    "ActiveRecord::ConnectionAdapters::PostgreSQLProxyAdapter",
    "active_record/connection_adapters/postgresql_proxy_adapter"
  )
end

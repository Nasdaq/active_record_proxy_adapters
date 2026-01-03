# frozen_string_literal: true

require "active_record_proxy_adapters/active_record_context"
require "active_record_proxy_adapters/hijackable"
require "active_record_proxy_adapters/trilogy_proxy"
require "active_record/connection_adapters/trilogy_adapter"
require "active_record/tasks/trilogy_proxy_database_tasks"

module ActiveRecord
  module ConnectionAdapters
    # This adapter is a proxy to the original TrilogyAdapter, allowing the use of the
    # ActiveRecordProxyAdapters::PrimaryReplicaProxy.
    class TrilogyProxyAdapter < TrilogyAdapter
      include ActiveRecordProxyAdapters::Hijackable

      ADAPTER_NAME = "TrilogyProxy"

      delegate_to_proxy(*ActiveRecordProxyAdapters::ActiveRecordContext.hijackable_methods)

      def initialize(...)
        @proxy = ActiveRecordProxyAdapters::TrilogyProxy.new(self)

        super
      end

      private

      attr_reader :proxy
    end
  end
end

if ActiveRecordProxyAdapters::ActiveRecordContext.active_record_v7_2_or_greater?
  ActiveRecord::ConnectionAdapters.register(
    "trilogy_proxy",
    "ActiveRecord::ConnectionAdapters::TrilogyProxyAdapter",
    "active_record/connection_adapters/trilogy_proxy_adapter"
  )
end

ActiveSupport.run_load_hooks(:active_record_trilogyproxyadapter, ActiveRecord::ConnectionAdapters::TrilogyProxyAdapter)

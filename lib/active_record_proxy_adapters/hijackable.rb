# frozen_string_literal: true

require "active_record/tasks/postgresql_proxy_database_tasks"
require "active_record/connection_adapters/postgresql_adapter"

module ActiveRecordProxyAdapters
  # Defines mixins to delegate specific methods from the proxy to the adapter.
  module Hijackable
    extend ActiveSupport::Concern

    class_methods do # rubocop:disable Metrics/BlockLength
      # Renames the methods from the original Adapter using the proxy suffix (_unproxied)
      # and delegate the original method name to the proxy.
      # Example: delegate_to_proxy(:execute) creates a method `execute_unproxied`,
      # while delegating :execute to the proxy.
      # @param method_name [Array<Symbol>] the names of methods to be redefined.
      def delegate_to_proxy(*method_names)
        method_names.each do |method_name|
          proxy_method_name = proxy_method_name_for(method_name)
          proxy_method_private = private_method_defined?(method_name)

          # some adapter methods are private. We need to make them public before aliasing.
          public method_name if proxy_method_private

          alias_method proxy_method_name, method_name

          # If adapter method was originally private. We now make them private again.
          private method_name, proxy_method_name if proxy_method_private
        end

        delegate(*method_names, to: :proxy)
      end

      # Defines which methods should be hijacked from the original adapter and use the proxy
      # @param method_names [Array<Symbol>] the list of method names from the adapter
      def hijack_method(*method_names) # rubocop:disable Metrics/MethodLength
        @hijacked_methods ||= Set.new
        @hijacked_methods += Set.new(method_names)

        method_names.each do |method_name|
          define_method(method_name) do |*args, **kwargs, &block|
            proxy_bypass_method = "#{method_name}#{unproxied_method_suffix}"
            sql_string          = coerce_query_to_string(args.first)

            appropriate_connection(sql_string) do |conn|
              method_to_call = conn == primary_connection ? proxy_bypass_method : method_name

              conn.send(method_to_call, *args, **kwargs, &block)
            end
          end
        end
      end

      def unproxied_method_suffix
        "_unproxied"
      end

      private

      def proxy_method_name_for(method_name)
        :"#{method_name}#{unproxied_method_suffix}"
      end
    end

    included do
      def unproxied_method_suffix
        self.class.unproxied_method_suffix
      end
    end
  end
end

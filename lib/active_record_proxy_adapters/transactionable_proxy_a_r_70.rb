# frozen_string_literal: true

module ActiveRecordProxyAdapters
  module TransactionableProxyAR70 # rubocop:disable Style/Documentation
    extend ActiveSupport::Concern

    included do
      def begin_db_transaction # :nodoc:
        bypass_proxy_or_else("BEGIN", "TRANSACTION") { super }
      end

      def commit_db_transaction # :nodoc:
        bypass_proxy_or_else("COMMIT", "TRANSACTION") { super }
      end

      def exec_rollback_db_transaction # :nodoc:
        bypass_proxy_or_else("ROLLBACK", "TRANSACTION") { super }
      end

      private

      def bypass_proxy_or_else(*args)
        method_name = proxy_method_name_for(:execute)

        return public_send(method_name, *args) if respond_to?(method_name)

        yield
      end
    end
  end
end

# frozen_string_literal: true

require "active_record_proxy_adapters/configuration"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "concurrent-ruby"
require "active_record_proxy_adapters/active_record_context"

module ActiveRecordProxyAdapters
  # This is the base class for all proxies. It defines the methods that should be proxied
  # and the logic to determine which database to use.
  class PrimaryReplicaProxy # rubocop:disable Metrics/ClassLength
    # All queries that match these patterns should be sent to the primary database
    SQL_PRIMARY_MATCHERS = [
      /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
      /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i
    ].map(&:freeze).freeze
    # All queries that match these patterns should be sent to the replica database
    SQL_REPLICA_MATCHERS     = [/\A\s*(select|with\s[\s\S]*\)\s*select)\s/i].map(&:freeze).freeze
    # All queries that match these patterns should be sent to all databases
    SQL_ALL_MATCHERS         = [/\A\s*set\s/i].map(&:freeze).freeze
    # Local sets queries should not be sent to all datbases
    SQL_SKIP_ALL_MATCHERS    = [/\A\s*set\s+local\s/i].map(&:freeze).freeze
    # These patterns define which database statments are considered write statments, so we can shortly re-route all
    # requests to the primary database so the replica has time to replicate
    WRITE_STATEMENT_MATCHERS = [/\ABEGIN/i, /\ACOMMIT/i, /INSERT\sINTO\s/i, /UPDATE\s/i, /DELETE\sFROM\s/i,
                                /DROP\s/i].map(&:freeze).freeze
    UNPROXIED_METHOD_SUFFIX  = "_unproxied"

    # Defines which methods should be hijacked from the original adapter and use the proxy
    # @param method_names [Array<Symbol>] the list of method names from the adapter
    def self.hijack_method(*method_names) # rubocop:disable Metrics/MethodLength
      @hijacked_methods ||= Set.new
      @hijacked_methods += Set.new(method_names)

      method_names.each do |method_name|
        define_method(method_name) do |*args, **kwargs, &block|
          proxy_bypass_method = "#{method_name}#{UNPROXIED_METHOD_SUFFIX}"
          sql_string          = coerce_query_to_string(args.first)

          appropriate_connection(sql_string) do |conn|
            method_to_call = conn == primary_connection ? proxy_bypass_method : method_name

            conn.send(method_to_call, *args, **kwargs, &block)
          end
        end
      end
    end

    def self.hijacked_methods
      @hijacked_methods.to_a
    end

    # @param primary_connection [ActiveRecord::ConnectionAdatpers::AbstractAdapter]
    def initialize(primary_connection)
      @primary_connection    = primary_connection
      @last_write_at         = 0
      @active_record_context = ActiveRecordContext.new
    end

    private

    attr_reader :primary_connection, :last_write_at, :active_record_context

    delegate :connection_handler, :connected_to_stack, to: :connection_class
    delegate :reading_role, :writing_role, to: :active_record_context

    def replica_pool_unavailable?
      !replica_pool
    end

    def replica_pool
      # use default handler if the connection pool for specific class is not found
      specific_replica_pool || default_replica_pool
    end

    def specific_replica_pool
      connection_handler.retrieve_connection_pool(connection_class.name, role: reading_role)
    end

    def default_replica_pool
      connection_handler.retrieve_connection_pool(ActiveRecord::Base.name, role: reading_role)
    end

    def connection_class
      active_record_context.connection_class_for(primary_connection)
    end

    def coerce_query_to_string(sql_or_arel)
      sql_or_arel.respond_to?(:to_sql) ? sql_or_arel.to_sql : sql_or_arel.to_s
    end

    def appropriate_connection(sql_string, &block)
      roles_for(sql_string).map do |role|
        connection_for(role, sql_string) do |connection|
          block.call(connection)
        end
      end.last
    end

    def roles_for(sql_string)
      return [top_of_connection_stack_role] if top_of_connection_stack_role.present?

      if need_all?(sql_string)
        [reading_role, writing_role]
      elsif need_primary?(sql_string)
        [writing_role]
      else
        [reading_role]
      end
    end

    def top_of_connection_stack_role
      return if connected_to_stack.empty?

      top = connected_to_stack.last
      role = top[:role]
      return unless role.present?

      [reading_role, writing_role].include?(role) ? role : nil
    end

    def connection_for(role, sql_string)
      connection = primary_connection if role == writing_role || replica_pool_unavailable?
      connection ||= checkout_replica_connection

      result = yield(connection)

      update_primary_latest_write_timestamp if !replica_connection?(connection) && write_statement?(sql_string)

      result
    ensure
      replica_connection?(connection) && replica_pool.checkin(connection)
    end

    def replica_connection?(connection)
      connection && connection != primary_connection
    end

    def checkout_replica_connection
      replica_pool.checkout(checkout_timeout)
    # rescue NoDatabaseError to avoid crashing when running db:create rake task
    # rescue ConnectionNotEstablished to handle connectivity issues in the replica
    # (for example, replication delay)
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      primary_connection
    end

    # @return [TrueClass] if there has been a write within the last {#proxy_delay} seconds
    # @return [TrueClass] if sql_string matches a write statement (i.e. INSERT, UPDATE, DELETE, SELECT FOR UPDATE)
    # @return [FalseClass] if sql_string matches a read statement (i.e. SELECT)
    def need_primary?(sql_string)
      return true if recent_write_to_primary?

      return true  if in_transaction?
      return true  if SQL_PRIMARY_MATCHERS.any?(&match_sql?(sql_string))
      return false if SQL_REPLICA_MATCHERS.any?(&match_sql?(sql_string))

      true
    end

    def need_all?(sql_string)
      return false if SQL_SKIP_ALL_MATCHERS.any?(&match_sql?(sql_string))

      SQL_ALL_MATCHERS.any?(&match_sql?(sql_string))
    end

    def write_statement?(sql_string)
      WRITE_STATEMENT_MATCHERS.any?(&match_sql?(sql_string))
    end

    def match_sql?(sql_string)
      proc { |matcher| matcher.match?(sql_string) }
    end

    # TODO: implement a context API to re-route requests to the primary database if a recent query was sent to it to
    # avoid replication delay issues
    # @return Boolean
    def recent_write_to_primary?
      Concurrent.monotonic_time - last_write_at < proxy_delay
    end

    def in_transaction?
      primary_connection.open_transactions.positive?
    end

    def update_primary_latest_write_timestamp
      @last_write_at = Concurrent.monotonic_time
    end

    def proxy_delay
      proxy_config.proxy_delay
    end

    def checkout_timeout
      proxy_config.checkout_timeout
    end

    def proxy_config
      ActiveRecordProxyAdapters.config
    end
  end
end

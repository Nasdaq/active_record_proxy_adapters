# frozen_string_literal: true

require "active_record_proxy_adapters/active_record_context"
require "active_record_proxy_adapters/configuration"
require "active_record_proxy_adapters/contextualizer"
require "active_record_proxy_adapters/hijackable"
require "active_record_proxy_adapters/mixin/configuration"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

module ActiveRecordProxyAdapters
  # This is the base class for all proxies. It defines the methods that should be proxied
  # and the logic to determine which database to use.
  class PrimaryReplicaProxy # rubocop:disable Metrics/ClassLength
    include Hijackable
    include Contextualizer
    include Mixin::Configuration

    # All queries that match these patterns should be sent to the primary database
    SQL_PRIMARY_MATCHERS = [
      /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
      /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i
    ].map(&:freeze).freeze

    CTE_MATCHER = /\A\s*WITH\s+(?<CTE>\S+\s+AS\s+\(\s?[\s\S]*\))/i
    # All queries that match these patterns should be sent to the replica database
    SQL_REPLICA_MATCHERS = [
      /\A\s*(select)\s/i,
      /#{CTE_MATCHER.source}\s*select/i
    ].map(&:freeze).freeze
    # All queries that match these patterns should be sent to all databases
    SQL_ALL_MATCHERS         = [/\A\s*set\s/i].map(&:freeze).freeze
    # Local sets queries should not be sent to all datbases
    SQL_SKIP_ALL_MATCHERS    = [/\A\s*set\s+local\s/i].map(&:freeze).freeze
    # These patterns define which database statments are considered write statments, so we can shortly re-route all
    # requests to the primary database so the replica has time to replicate
    WRITE_STATEMENT_MATCHERS = [
      /\ABEGIN/i,
      /\ACOMMIT/i,
      /\AROLLBACK/i,
      /INSERT\s[\s\S]*INTO\s[\s\S]*/i,
      /UPDATE\s[\s\S]*/i,
      /DELETE\s[\s\S]*FROM\s[\s\S]*/i,
      /DROP\s/i
    ].map(&:freeze).freeze

    # Abstract adapter methods that should be proxied.
    hijack_method(*ActiveRecordContext.hijackable_methods)

    def self.hijacked_methods
      @hijacked_methods.to_a
    end

    # @param primary_connection [ActiveRecord::ConnectionAdatpers::AbstractAdapter]
    def initialize(primary_connection)
      @primary_connection    = primary_connection
      @active_record_context = ActiveRecordContext.new
    end

    private

    attr_reader :primary_connection, :active_record_context

    delegate :connection_handler, to: :connection_class
    delegate :reading_role, :writing_role, to: :active_record_context

    # We need to call .verify! to ensure `configure_connection` is called on the instance before attempting to use it.
    # This is necessary because the connection may have been lazily initialized and is an unintended side effect from a
    # change in Rails to defer connection verification: https://github.com/rails/rails/pull/44576
    # verify! cannot be called before the object is initialized and because of how the proxy hooks into the connection
    # instance, it has to be done lazily (hence the memoization). Ideally, we shouldn't have to worry about this at all
    # But there is tight coupling between methods in ActiveRecord::ConnectionAdapters::AbstractAdapter and
    # its descendants which will require significant refactoring to be decoupled.
    # See https://github.com/rails/rails/issues/51780
    def verified_primary_connection
      @verified_primary_connection ||= begin
        connected_to(role: writing_role) { primary_connection.verify! }

        primary_connection
      end
    end

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

    def roles_for(sql_string) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      return [top_of_connection_stack_role] if top_of_connection_stack_role.present?
      return [writing_role] if recent_write_to_primary? || in_transaction?

      cache_key = cache_key_for(sql_string)
      cache_store.fetch(cache_key) do
        ActiveSupport::Notifications.instrument("active_record_proxy_adapters.cache_miss",
                                                cache_key: cache_key, sql: sql_string) do
          if need_all?(sql_string)
            [reading_role, writing_role]
          elsif need_primary?(sql_string)
            [writing_role]
          else
            [reading_role]
          end
        end
      end
    end

    def top_of_connection_stack_role
      return if connected_to_stack.empty?

      top = connected_to_stack.last
      role = top[:role]
      return unless role.present?

      [reading_role, writing_role].include?(role) ? role : nil
    end

    def connected_to_stack
      return connection_class.connected_to_stack if connection_class.respond_to?(:connected_to_stack)

      # handle Rails 7.2+ pending migrations Connection
      return [{ role: writing_role }] if pending_migration_connection?

      []
    end

    def pending_migration_connection?
      active_record_context.active_record_v7_1_or_greater? &&
        connection_class.name == "ActiveRecord::PendingMigrationConnection"
    end

    def connection_for(role, sql_string)
      connection = verified_primary_connection if role == writing_role || replica_pool_unavailable?

      connection ||= checkout_replica_connection

      result = connected_to(role:) { yield connection }

      update_primary_latest_write_timestamp if !replica_connection?(connection) && write_statement?(sql_string)

      result
    ensure
      replica_connection?(connection) && replica_pool.checkin(connection)
    end

    def connected_to(role:, &block)
      return block.call unless connection_class.respond_to?(:connected_to)

      connection_class.connected_to(role:, &block)
    end

    def replica_connection?(connection)
      connection && connection != primary_connection
    end

    def checkout_replica_connection
      replica_pool.checkout(checkout_timeout(primary_connection_name))
    # rescue NoDatabaseError to avoid crashing when running db:create rake task
    # rescue ConnectionNotEstablished to handle connectivity issues in the replica
    # (for example, replication delay)
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      primary_connection
    end

    # @return [TrueClass] if sql_string matches a write statement (i.e. INSERT, UPDATE, DELETE, SELECT FOR UPDATE)
    # @return [FalseClass] if sql_string matches a read statement (i.e. SELECT)
    def need_primary?(sql_string)
      return true  if cte_for_write?(sql_string)
      return true  if SQL_PRIMARY_MATCHERS.any?(&match_sql?(sql_string))
      return false if SQL_REPLICA_MATCHERS.any?(&match_sql?(sql_string))

      true
    end

    def cte_for_write?(sql_string)
      CTE_MATCHER.match?(sql_string) &&
        WRITE_STATEMENT_MATCHERS.any?(&match_sql?(sql_string))
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

    # @return Boolean
    def recent_write_to_primary?
      proxy_context.recent_write_to_primary?(primary_connection_name)
    end

    def in_transaction?
      primary_connection.open_transactions.positive?
    end

    def update_primary_latest_write_timestamp
      proxy_context.update_for(primary_connection_name)
    end

    def primary_connection_name
      @primary_connection_name ||= primary_connection.pool.try(:db_config).try(:name).try(:to_s)
    end

    def proxy_context
      self.current_context ||= context_store.new({})
    end
  end
end

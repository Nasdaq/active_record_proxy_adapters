# frozen_string_literal: true

begin
  require "active_record/connection_adapters/postgresql_proxy_adapter"
rescue LoadError
  # Postgres not available
  return
end

module ActiveRecordProxyAdapters
  # Module to extend ActiveRecord::Base with the connection handling methods.
  # Required to make adapter work in ActiveRecord versions <= 7.2.x
  module PostgreSQL
    module ConnectionHandling # rubocop:disable Style/Documentation
      def postgresql_proxy_adapter_class
        ::ActiveRecord::ConnectionAdapters::PostgreSQLProxyAdapter
      end

      # This method is a copy and paste from Rails' postgresql_connection,
      # replacing PostgreSQLAdapter by PostgreSQLProxyAdapter
      # This is required by ActiveRecord versions <= 7.2.x to establish a connection using the adapter.
      def postgresql_proxy_connection(config) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        conn_params = config.symbolize_keys.compact

        # Map ActiveRecords param names to PGs.
        conn_params[:user]   = conn_params.delete(:username) if conn_params[:username]
        conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

        # Forward only valid config params to PG::Connection.connect.
        valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
        conn_params.slice!(*valid_conn_param_keys)

        postgresql_proxy_adapter_class.new(
          postgresql_proxy_adapter_class.new_client(conn_params),
          logger,
          conn_params,
          config
        )
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.extend(ActiveRecordProxyAdapters::PostgreSQL::ConnectionHandling)
end

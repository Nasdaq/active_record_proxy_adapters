# frozen_string_literal: true

require "active_record/connection_adapters/postgresql_proxy_adapter"
require "active_record/connection_adapters/mysql2_proxy_adapter"

module ActiveRecordProxyAdapters
  # Module to extend ActiveRecord::Base with the connection handling methods.
  # Required to make adapter work in ActiveRecord versions <= 7.2.x
  module ConnectionHandling
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

    def mysql2_proxy_adapter_class
      ::ActiveRecord::ConnectionAdapters::Mysql2ProxyAdapter
    end

    # This method is a copy and paste from Rails' mysql2_connection,
    # replacing Mysql2Adapter by Mysql2ProxyAdapter
    # This is required by ActiveRecord versions <= 7.2.x to establish a connection using the adapter.
    def mysql2_proxy_connection(config) # rubocop:disable Metrics/MethodLength
      config = config.symbolize_keys
      config[:flags] ||= 0

      if config[:flags].is_a? Array
        config[:flags].push "FOUND_ROWS"
      else
        config[:flags] |= Mysql2::Client::FOUND_ROWS
      end

      mysql2_proxy_adapter_class.new(
        mysql2_proxy_adapter_class.new_client(config),
        logger,
        nil,
        config
      )
    end
  end
end

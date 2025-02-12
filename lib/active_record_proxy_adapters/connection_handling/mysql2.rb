# frozen_string_literal: true

begin
  require "active_record/connection_adapters/mysql2_proxy_adapter"
rescue LoadError
  # mysql2 not available
  return
end

module ActiveRecordProxyAdapters
  # Module to extend ActiveRecord::Base with the connection handling methods.
  # Required to make adapter work in ActiveRecord versions <= 7.2.x
  module ConnectionHandling
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

# frozen_string_literal: true

begin
  require "active_record/connection_adapters/sqlite3_proxy_adapter"
rescue LoadError
  # sqlite3 not available
  return
end

module ActiveRecordProxyAdapters
  module SQLite3
    # Module to extend ActiveRecord::Base with the connection handling methods.
    # Required to make adapter work in ActiveRecord versions <= 7.2.x
    module ConnectionHandling
      def sqlite3_proxy_adapter_class
        ActiveRecord::ConnectionAdapters::SQLite3ProxyAdapter
      end

      def sqlite3_proxy_connection(config)
        sqlite3_proxy_adapter_class.new(config)
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.extend(ActiveRecordProxyAdapters::SQLite3::ConnectionHandling)
end

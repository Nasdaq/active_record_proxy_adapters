# frozen_string_literal: true

require "active_support"

module ActiveRecordProxyAdapters
  module Railties
    # Hooks into rails boot process to load the SQLite3 Proxy adapter.
    class SQLite3Proxy < Rails::Railtie
      require "active_record_proxy_adapters/connection_handling/sqlite3_proxy"

      config.to_prepare do
        Rails.autoloaders.each do |autoloader|
          autoloader.inflector.inflect(
            "sqlite3_proxy_adapter" => "SQLite3ProxyAdapter"
          )
        end
      end
    end
  end
end

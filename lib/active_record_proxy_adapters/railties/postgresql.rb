# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/core"

module ActiveRecordProxyAdapters
  module Railties
    # Hooks into rails boot process to load the PostgreSQL Proxy adapter.
    class PostgreSQLProxy < Rails::Railtie
      require "active_record_proxy_adapters/connection_handling/postgresql_proxy"

      config.to_prepare do
        Rails.autoloaders.each do |autoloader|
          autoloader.inflector.inflect(
            "postgresql_proxy_adapter" => "PostgreSQLProxyAdapter"
          )
        end
      end
    end
  end
end

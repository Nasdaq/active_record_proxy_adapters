# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/railties/postgresql"
require "active_record_proxy_adapters/railties/mysql2"

module ActiveRecordProxyAdapters
  # Hooks into rails boot process to extend ActiveRecord with the proxy adapter.
  class Railtie < Rails::Railtie
    require "active_record_proxy_adapters/connection_handling/trilogy"
    require "active_record_proxy_adapters/connection_handling/sqlite3"
    require "active_record_proxy_adapters/middleware"

    config.to_prepare do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect(
          "sqlite3_proxy_adapter" => "SQLite3ProxyAdapter"
        )
      end
    end

    initializer "active_record_proxy_adapters.configure_rails_initialization" do |app|
      app.middleware.use ActiveRecordProxyAdapters::Middleware
    end
  end
end

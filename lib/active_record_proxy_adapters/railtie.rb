# frozen_string_literal: true

require "active_support"

module ActiveRecordProxyAdapters
  # Hooks into rails boot process to extend ActiveRecord with the proxy adapter.
  class Railtie < Rails::Railtie
    require "active_record_proxy_adapters/connection_handling"
    require "active_record_proxy_adapters/middleware"
    require "active_record_proxy_adapters/rake"

    config.to_prepare do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect(
          "postgresql_proxy_adapter" => "PostgreSQLProxyAdapter"
        )
        autoloader.inflector.inflect(
          "sqlite3_proxy_adapter" => "SQLite3ProxyAdapter"
        )
      end
    end

    initializer "active_record_proxy_adapters.configure_rails_initialization" do |app|
      app.middleware.use ActiveRecordProxyAdapters::Middleware
    end

    rake_tasks do
      ActiveRecordProxyAdapters::Rake.load_tasks
      ActiveRecordProxyAdapters::Rake.enhance_db_tasks
    end
  end
end

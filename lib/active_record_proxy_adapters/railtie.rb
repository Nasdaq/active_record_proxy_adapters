# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/railties/postgresql"
require "active_record_proxy_adapters/railties/mysql2"
require "active_record_proxy_adapters/railties/trilogy"
require "active_record_proxy_adapters/railties/sqlite3"

module ActiveRecordProxyAdapters
  # Hooks into rails boot process to extend ActiveRecord with the proxy adapter.
  class Railtie < Rails::Railtie
    require "active_record_proxy_adapters/middleware"

    initializer "active_record_proxy_adapters.configure_rails_initialization" do |app|
      app.middleware.use ActiveRecordProxyAdapters::Middleware
    end
  end
end

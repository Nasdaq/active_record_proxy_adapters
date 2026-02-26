# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/core"
require "active_record_proxy_adapters/railties/mysql2"
require "active_record_proxy_adapters/railties/postgresql"
require "active_record_proxy_adapters/railties/rack_middleware"
require "active_record_proxy_adapters/railties/sqlite3"
require "active_record_proxy_adapters/railties/trilogy"

module ActiveRecordProxyAdapters
  # Hooks into rails boot process to extend ActiveRecord with the proxy adapter.
  class Railtie < Rails::Railtie
    require "active_record_proxy_adapters/rake"

    rake_tasks do
      ActiveRecordProxyAdapters::Rake.load_tasks
      ActiveRecordProxyAdapters::Rake.enhance_db_tasks
    end
  end
end

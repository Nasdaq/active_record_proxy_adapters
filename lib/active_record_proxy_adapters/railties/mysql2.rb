# frozen_string_literal: true

require "active_support"
require "active_record_proxy_adapters/core"

module ActiveRecordProxyAdapters
  module Railties
    # Hooks into rails boot process to load the Mysql2 Proxy adapter.
    class Mysql2Proxy < Rails::Railtie
      require "active_record_proxy_adapters/connection_handling/mysql2_proxy"
    end
  end
end
